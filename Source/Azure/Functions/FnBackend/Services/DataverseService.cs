using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.PowerPlatform.Dataverse.Client;
using Microsoft.Crm.Sdk.Messages;
using Microsoft.Identity.Client;
using Microsoft.AspNetCore.Http;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace FnBackend.Services;

/// <summary>
/// Dataverse service implementation with support for:
/// - S2S (Service-to-Service) authentication using client credentials
/// - OBO (On-Behalf-Of) authentication for user delegation
/// </summary>
public class DataverseService : IDataverseService
{
    private readonly ILogger<DataverseService> _logger;
    private readonly IConfiguration _configuration;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly string _dataverseUrl;
    private readonly string _clientId;
    private readonly string _clientSecret;
    private readonly string _tenantId;

    public DataverseService(
        ILogger<DataverseService> logger,
        IConfiguration configuration,
        IHttpContextAccessor httpContextAccessor)
    {
        _logger = logger;
        _configuration = configuration;
        _httpContextAccessor = httpContextAccessor;

        _dataverseUrl = configuration["Dataverse:Url"]
            ?? throw new InvalidOperationException("Dataverse:Url not found in configuration");

        // For OBO flow, use AzureAd configuration
        _clientId = configuration["Dataverse:AppRegistration:ClientId"]
            ?? throw new InvalidOperationException("Dataverse:AppRegistration:ClientId not found in configuration");

        _clientSecret = configuration["Dataverse:AppRegistration:ClientSecret"]
            ?? throw new InvalidOperationException("Dataverse:AppRegistration:ClientSecret not found in configuration");

        _tenantId = configuration["Dataverse:AppRegistration:TenantId"]
            ?? throw new InvalidOperationException("Dataverse:AppRegistration:TenantId not found in configuration");
    }

    /// <summary>
    /// Creates a ServiceClient using S2S (Service-to-Service) authentication with client credentials.
    /// Use this for background jobs or service-level operations, Azure Event-Hub or Service Bus to Dataverse integrations.
    /// </summary>
    private ServiceClient CreateServiceClientForS2S()
    {
        _logger.LogInformation("Creating Dataverse ServiceClient for S2S authentication");

        // Create connection string for app registration authentication
        var connectionString = $"AuthType=ClientSecret;Url={_dataverseUrl};ClientId={_clientId};ClientSecret={_clientSecret}";

        // Create ServiceClient with connection string
        var serviceClient = new ServiceClient(connectionString, _logger);

        if (!serviceClient.IsReady)
        {
            var lastError = serviceClient.LastError;
            _logger.LogError("Failed to connect to Dataverse using S2S: {Error}", lastError);
            throw new InvalidOperationException($"Unable to connect to Dataverse: {lastError}");
        }

        _logger.LogInformation("Successfully connected to Dataverse using S2S authentication");
        return serviceClient;
    }

    /// <summary>
    /// Creates a ServiceClient using OBO (On-Behalf-Of) flow with explicit user token.
    /// </summary>
    private async Task<ServiceClient> CreateServiceClientForOBOAsync()
    {
        var authorizationHeader = _httpContextAccessor.HttpContext.Request.Headers["Authorization"].FirstOrDefault();

        if (string.IsNullOrEmpty(authorizationHeader) || !authorizationHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("Missing or invalid Authorization header");
        }

        var userAccessToken = authorizationHeader.Substring("Bearer ".Length).Trim();

        if (string.IsNullOrWhiteSpace(userAccessToken))
        {
            throw new ArgumentException("User access token is required", nameof(userAccessToken));
        }

        _logger.LogInformation("Acquiring Dataverse token using OBO flow");

        // Create confidential client application
        var app = ConfidentialClientApplicationBuilder
            .Create(_clientId)
            .WithClientSecret(_clientSecret)
            .WithAuthority(new Uri($"https://login.microsoftonline.com/{_tenantId}"))
            .Build();

        // Request Dataverse token using OBO flow
        var scopes = new[] { $"{_dataverseUrl}/.default" };
        var userAssertion = new UserAssertion(userAccessToken);

        try
        {
            var result = await app.AcquireTokenOnBehalfOf(scopes, userAssertion)
                .ExecuteAsync();

            _logger.LogInformation("Successfully acquired Dataverse token using OBO flow");

            // Create ServiceClient with the OBO token
            var serviceClient = new ServiceClient(
                instanceUrl: new Uri(_dataverseUrl),
                tokenProviderFunction: async (url) =>
                {
                    // Get a fresh token when needed
                    var freshResult = await app.AcquireTokenOnBehalfOf(scopes, userAssertion)
                        .ExecuteAsync();
                    return freshResult.AccessToken;
                },
                useUniqueInstance: true,
                logger: _logger
            );

            if (!serviceClient.IsReady)
            {
                throw new InvalidOperationException($"Unable to connect to Dataverse: {serviceClient.LastError}");
            }

            _logger.LogInformation("Successfully connected to Dataverse using OBO token");
            return serviceClient;
        }
        catch (MsalException ex)
        {
            _logger.LogError(ex, "MSAL exception during OBO token acquisition: {Error}", ex.Message);
            throw new InvalidOperationException($"Failed to acquire Dataverse token using OBO flow: {ex.Message}", ex);
        }
    }

    public async Task<WhoAmIResponse> WhoAmIAsync()
    {
        _logger.LogInformation("Executing WhoAmI request using OBO flow from HttpContext");

        using var serviceClient = await CreateServiceClientForOBOAsync();

        var request = new WhoAmIRequest();
        var response = (WhoAmIResponse)await serviceClient.ExecuteAsync(request);

        _logger.LogInformation(
            "WhoAmI OBO response - UserId: {UserId}, BusinessUnitId: {BusinessUnitId}, OrganizationId: {OrganizationId}",
            response.UserId,
            response.BusinessUnitId,
            response.OrganizationId);

        return response;
    }

    public async Task<WhoAmIResponse> WhoAmIS2SAsync()
    {
        _logger.LogInformation("Executing WhoAmI request for S2S authentication");

        // 1. Extract the access token from the Authorization header
        var authorizationHeader = _httpContextAccessor.HttpContext.Request.Headers["Authorization"].FirstOrDefault();

        if (string.IsNullOrEmpty(authorizationHeader) || !authorizationHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("Missing or invalid Authorization header");
        }

        var accessToken = authorizationHeader.Substring("Bearer ".Length).Trim();

        // 2. Decode the JWT token to extract the app registration client ID (azp or appid claim)
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(accessToken);

        // Try to get the client ID from common claims (azp for delegated, appid for app-only)
        var clientId = jwtToken.Claims.FirstOrDefault(c => c.Type == "azp")?.Value
                      ?? jwtToken.Claims.FirstOrDefault(c => c.Type == "appid")?.Value
                      ?? jwtToken.Claims.FirstOrDefault(c => c.Type == "aud")?.Value;

        if (string.IsNullOrEmpty(clientId))
        {
            throw new InvalidOperationException("Unable to extract client ID (azp/appid) from access token");
        }

        _logger.LogInformation("Extracted client ID from token: {ClientId}", clientId);

        // 3. Create S2S service client to query for the application user
        using var s2sServiceClient = CreateServiceClientForS2S();

        // 4. Query Dataverse to find the application user (systemuser) with matching applicationid
        var query = new QueryExpression("systemuser")
        {
            ColumnSet = new ColumnSet("systemuserid", "fullname", "applicationid"),
            Criteria = new FilterExpression
            {
                Conditions =
                {
                    new ConditionExpression("applicationid", ConditionOperator.Equal, Guid.Parse(clientId))
                }
            }
        };

        var results = await s2sServiceClient.RetrieveMultipleAsync(query);

        if (results.Entities.Count == 0)
        {
            throw new InvalidOperationException($"No application user found in Dataverse for client ID: {clientId}");
        }

        if (results.Entities.Count > 1)
        {
            _logger.LogWarning("Multiple application users found for client ID: {ClientId}. Using the first one.", clientId);
        }

        var applicationUser = results.Entities[0];
        var applicationUserId = applicationUser.Id;

        _logger.LogInformation(
            "Found application user - ID: {UserId}, Name: {Name}",
            applicationUserId,
            applicationUser.GetAttributeValue<string>("fullname"));

        // 5. Set CallerId to impersonate the application user and execute WhoAmI
        s2sServiceClient.CallerId = applicationUserId;

        var whoAmIRequest = new WhoAmIRequest();
        var whoAmIResponse = (WhoAmIResponse)await s2sServiceClient.ExecuteAsync(whoAmIRequest);

        _logger.LogInformation(
            "WhoAmI S2S response - UserId: {UserId}, BusinessUnitId: {BusinessUnitId}, OrganizationId: {OrganizationId}",
            whoAmIResponse.UserId,
            whoAmIResponse.BusinessUnitId,
            whoAmIResponse.OrganizationId);

        return whoAmIResponse;
    }
}
