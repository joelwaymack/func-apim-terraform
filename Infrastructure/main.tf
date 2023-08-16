locals {
  resource_prefix = var.unique_id
}

resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = "${local.resource_prefix}-rg"
}

resource "azurerm_storage_account" "stg" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.rg.location
  name                     = "${local.resource_prefix}stg"
  resource_group_name      = azurerm_resource_group.rg.name
}

resource "azurerm_log_analytics_workspace" "log" {
  name                = "${local.resource_prefix}-log"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "app_insights" {
  location            = azurerm_resource_group.rg.location
  name                = "${local.resource_prefix}-ai"
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log.id
}

resource "azurerm_service_plan" "func_plan" {
  name                = "${local.resource_prefix}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "EP1"
}

resource "azurerm_linux_function_app" "func" {
  name                = "${local.resource_prefix}-func"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.stg.name
  storage_account_access_key = azurerm_storage_account.stg.primary_access_key
  service_plan_id            = azurerm_service_plan.func_plan.id


  functions_extension_version = "~4"

  site_config {
    application_stack {
      dotnet_version              = "7.0"
      use_dotnet_isolated_runtime = true
    }
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
    application_insights_key               = azurerm_application_insights.app_insights.instrumentation_key
  }
}

resource "azurerm_api_management" "apim" {
  name                = "${local.resource_prefix}-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "joel"
  publisher_email     = "joel.waymack@microsoft.com"

  sku_name = "Developer_1"

  timeouts {
    create = "120m"
  }
}

data "azurerm_function_app_host_keys" "func_host_keys" {
  name                = azurerm_linux_function_app.func.name
  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_api_management_named_value" "apim_func_key_value" {
  name                = "orders-backend-func-key"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "orders-backend-func-key"
  value               = data.azurerm_function_app_host_keys.func_host_keys.default_function_key
}

resource "azurerm_api_management_backend" "func_backend" {
  name                = "orders-backend"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.func.default_hostname}/api/"
  title               = "Orders API"
  description         = "Orders API"
  resource_id         = "https://management.azure.com${azurerm_linux_function_app.func.id}"

  credentials {
    header = {
      x-functions-key = "{{${azurerm_api_management_named_value.apim_func_key_value.name}}}"
    }
  }
}

resource "azurerm_api_management_api" "api" {
  name                = "orders-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Orders API"
  path                = "orders-api"
  protocols           = ["https"]
}

resource "azurerm_api_management_api_operation" "get_orders" {
  operation_id        = "get-orders"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  api_name            = azurerm_api_management_api.api.name
  method              = "GET"
  url_template        = "/orders"
  description         = "Get all orders"
  display_name        = "Get Orders"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_policy" "backend_policy" {
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  api_name            = azurerm_api_management_api.api.name
  xml_content         = <<XML
      <policies>
        <inbound>
            <base />
            <set-backend-service id="backend-policy" backend-id="orders-backend" />
        </inbound>
      </policies>
    XML

  depends_on = [
    azurerm_api_management.apim,
    azurerm_api_management_api.api,
    azurerm_api_management_backend.func_backend
  ]
}
