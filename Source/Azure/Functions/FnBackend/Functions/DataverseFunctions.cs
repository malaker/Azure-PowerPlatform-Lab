using FnBackend.Configuration;
using FnBackend.Models;
using FnBackend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Extensions.Logging;
using Microsoft.OpenApi.Models;
using System.Net;
using System.Text;
using System.Text.Json;

namespace FnBackend.Functions;

/// <summary>
/// Azure Functions for Dataverse operations
/// </summary>
public class DataverseFunctions
{
    private readonly ILogger<DataverseFunctions> _logger;
    private readonly IDataverseService _dataverseService;

    public DataverseFunctions(ILogger<DataverseFunctions> logger, IDataverseService dataverseService)
    {
        _logger = logger;

        _dataverseService = dataverseService;

    }

    [Function("WhoAmI")]
    [Authorize] // Require OAuth2 authentication
    [OpenApiOperation(operationId: "WhoAmI", tags: new[] { "Dataverse" }, Summary = "Get current user information using OBO flow", Description = "Executes WhoAmI request against Dataverse using OAuth 2.0 On-Behalf-Of flow. Returns user, business unit, and organization IDs. Requires OAuth2 authentication.")]
    [OpenApiSecurity("oauth2", SecuritySchemeType.OAuth2, Flows = typeof(OAuth2Flows))]
    [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(WhoAmIResponseModel), Description = "Successful response with user information")]
    [OpenApiResponseWithBody(statusCode: HttpStatusCode.Unauthorized, contentType: "application/json", bodyType: typeof(ErrorResponseModel), Description = "Unauthorized - invalid or missing token")]
    [OpenApiResponseWithBody(statusCode: HttpStatusCode.InternalServerError, contentType: "application/json", bodyType: typeof(ErrorResponseModel), Description = "Error response")]
    public async Task<HttpResponseData> WhoAmI(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get")] HttpRequestData req)
    {
        _logger.LogInformation("WhoAmI function processing request using On-Behalf-Of flow.");

        try
        {
            // Execute WhoAmI request using OBO flow
            // The DataverseService will automatically extract the token from HttpContext
            var whoAmIResponse = await _dataverseService.WhoAmIAsync();

            // Create response object
            var responseData = new WhoAmIResponseModel
            {
                UserId = whoAmIResponse.UserId,
                BusinessUnitId = whoAmIResponse.BusinessUnitId,
                OrganizationId = whoAmIResponse.OrganizationId
            };

            // Create HTTP response
            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "application/json; charset=utf-8");

            // Serialize and write the response
            await response.WriteStringAsync(JsonSerializer.Serialize(responseData), Encoding.UTF8);

            return response;
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning(ex, "Unauthorized access attempt");

            var unauthorizedResponse = req.CreateResponse(HttpStatusCode.Unauthorized);
            unauthorizedResponse.Headers.Add("Content-Type", "application/json; charset=utf-8");
            await unauthorizedResponse.WriteStringAsync(JsonSerializer.Serialize(new ErrorResponseModel
            {
                Error = "Unauthorized",
                Message = ex.Message
            }), Encoding.UTF8);

            return unauthorizedResponse;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing WhoAmI request with OBO flow");

            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            errorResponse.Headers.Add("Content-Type", "application/json; charset=utf-8");
            await errorResponse.WriteStringAsync(JsonSerializer.Serialize(new ErrorResponseModel
            {
                Error = "Failed to execute WhoAmI request",
                Message = ex.Message
            }), Encoding.UTF8);

            return errorResponse;
        }
    }

    [Function("WhoAmIS2S")]
    [Authorize] // Require OAuth2 authentication
    [OpenApiOperation(operationId: "WhoAmIS2S", tags: new[] { "Dataverse" }, Summary = "Get application user information using S2S authentication", Description = "Executes WhoAmI request against Dataverse for Server-to-Server authentication. Extracts the calling app registration ID from the access token, finds the corresponding application user in Dataverse, and returns information about that application user. Requires OAuth2 authentication.")]
    [OpenApiSecurity("oauth2", SecuritySchemeType.OAuth2, Flows = typeof(OAuth2Flows))]
    [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(WhoAmIResponseModel), Description = "Successful response with application user information")]
    [OpenApiResponseWithBody(statusCode: HttpStatusCode.Unauthorized, contentType: "application/json", bodyType: typeof(ErrorResponseModel), Description = "Unauthorized - invalid or missing token")]
    [OpenApiResponseWithBody(statusCode: HttpStatusCode.NotFound, contentType: "application/json", bodyType: typeof(ErrorResponseModel), Description = "Application user not found in Dataverse")]
    [OpenApiResponseWithBody(statusCode: HttpStatusCode.InternalServerError, contentType: "application/json", bodyType: typeof(ErrorResponseModel), Description = "Error response")]
    public async Task<HttpResponseData> WhoAmIS2S(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get")] HttpRequestData req)
    {
        _logger.LogInformation("WhoAmIS2S function processing request using Server-to-Server authentication.");

        try
        {
            // Execute WhoAmI request using S2S flow
            // The DataverseService will extract the client ID from the token,
            // find the application user, and execute WhoAmI on behalf of that user
            var whoAmIResponse = await _dataverseService.WhoAmIS2SAsync();

            // Create response object
            var responseData = new WhoAmIResponseModel
            {
                UserId = whoAmIResponse.UserId,
                BusinessUnitId = whoAmIResponse.BusinessUnitId,
                OrganizationId = whoAmIResponse.OrganizationId
            };

            // Create HTTP response
            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "application/json; charset=utf-8");

            // Serialize and write the response
            await response.WriteStringAsync(JsonSerializer.Serialize(responseData), Encoding.UTF8);

            return response;
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning(ex, "Unauthorized access attempt");

            var unauthorizedResponse = req.CreateResponse(HttpStatusCode.Unauthorized);
            unauthorizedResponse.Headers.Add("Content-Type", "application/json; charset=utf-8");
            await unauthorizedResponse.WriteStringAsync(JsonSerializer.Serialize(new ErrorResponseModel
            {
                Error = "Unauthorized",
                Message = ex.Message
            }), Encoding.UTF8);

            return unauthorizedResponse;
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("No application user found"))
        {
            _logger.LogWarning(ex, "Application user not found in Dataverse");

            var notFoundResponse = req.CreateResponse(HttpStatusCode.NotFound);
            notFoundResponse.Headers.Add("Content-Type", "application/json; charset=utf-8");
            await notFoundResponse.WriteStringAsync(JsonSerializer.Serialize(new ErrorResponseModel
            {
                Error = "Application User Not Found",
                Message = ex.Message
            }), Encoding.UTF8);

            return notFoundResponse;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing WhoAmI S2S request");

            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            errorResponse.Headers.Add("Content-Type", "application/json; charset=utf-8");
            await errorResponse.WriteStringAsync(JsonSerializer.Serialize(new ErrorResponseModel
            {
                Error = "Failed to execute WhoAmI S2S request",
                Message = ex.Message
            }), Encoding.UTF8);

            return errorResponse;
        }
    }
}
