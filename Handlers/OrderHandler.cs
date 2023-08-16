using System.Globalization;
using System.Net;
using System.Reflection.Metadata.Ecma335;
using Company.Function.Models;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Microsoft.VisualBasic;

namespace Company.Function.Handlers;

public class OrderHandler
{
    private readonly ILogger _logger;
    private static readonly IList<Order> orders = new List<Order> {
        new Order { Id = Guid.NewGuid(), CustomerId = Guid.NewGuid() },
        new Order { Id = Guid.NewGuid(), CustomerId = Guid.NewGuid() },
        new Order { Id = Guid.NewGuid(), CustomerId = Guid.NewGuid() },
        new Order { Id = Guid.NewGuid(), CustomerId = Guid.NewGuid() },
        new Order { Id = Guid.NewGuid(), CustomerId = Guid.NewGuid() }
    };

    public OrderHandler(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<OrderHandler>();
    }

    [Function("GetOrders")]
    public HttpResponseData Run([HttpTrigger(AuthorizationLevel.Function, "get", Route = "orders")] HttpRequestData req)
    {
        _logger.LogInformation($"Returned {orders.Count} orders");

        var response = req.CreateResponse(HttpStatusCode.OK);
        response.WriteAsJsonAsync(orders);
        return response;
    }
}
