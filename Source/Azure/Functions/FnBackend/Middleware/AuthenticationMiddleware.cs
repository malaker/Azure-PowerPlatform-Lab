using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;

namespace FnBackend.Middleware;

public class AuthenticationMiddleware : IFunctionsWorkerMiddleware
{
    private readonly IConfiguration _configuration;
    private readonly ConfigurationManager<OpenIdConnectConfiguration> _configManager;

    public AuthenticationMiddleware(IConfiguration configuration)
    {
        _configuration = configuration;

        var tenantId = _configuration["AzureAd:TenantId"] ?? "common";
        var metadataAddress = $"https://login.microsoftonline.com/{tenantId}/v2.0/.well-known/openid-configuration";

        _configManager = new ConfigurationManager<OpenIdConnectConfiguration>(
            metadataAddress,
            new OpenIdConnectConfigurationRetriever(),
            new HttpDocumentRetriever());
    }

    public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
    {
        var httpReq = await context.GetHttpRequestDataAsync();

        if (httpReq != null)
        {
            // Check if the function requires authorization
            var targetMethod = context.FunctionDefinition.Name;
            var requiresAuth = context.FunctionDefinition.EntryPoint.Contains("WhoAmI");

            if (requiresAuth)
            {
                var authHeader = httpReq.Headers.FirstOrDefault(h => h.Key.Equals("Authorization", StringComparison.OrdinalIgnoreCase));

                if (authHeader.Value == null || !authHeader.Value.Any())
                {
                    await SendUnauthorizedResponse(httpReq, "Missing Authorization header");
                    return;
                }

                var token = authHeader.Value.First().Replace("Bearer ", string.Empty);

                try
                {
                    var claimsPrincipal = await ValidateToken(token);

                    // Attach claims principal to context
                    context.Items["User"] = claimsPrincipal;
                }
                catch (Exception ex)
                {
                    await SendUnauthorizedResponse(httpReq, $"Invalid token: {ex.Message}");
                    return;
                }
            }
        }

        await next(context);
    }

    private async Task<ClaimsPrincipal> ValidateToken(string token)
    {
        var config = await _configManager.GetConfigurationAsync();
        var clientId = _configuration["Dataverse:AppRegistration:ClientId"] ?? throw new InvalidOperationException("Dataverse:AppRegistration:ClientId is required");
        var tenantId = _configuration["Dataverse:AppRegistration:TenantId"] ?? throw new InvalidOperationException("Dataverse: AppRegistration:TenantId is required");
        var audience = $"api://{clientId}";
        
        // Build list of valid audiences
        var validAudiences = new List<string> { clientId, audience };

        var validationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuers = new[] {
                $"https://login.microsoftonline.com/{tenantId}/v2.0",
                $"https://sts.windows.net/{tenantId}/",
                $"https://login.microsoftonline.com/{tenantId}/"  // Added for managed identity
            },
            ValidateAudience = true,
            ValidAudiences = validAudiences,
            ValidateLifetime = true,
            IssuerSigningKeys = config.SigningKeys,
            ValidateIssuerSigningKey = true,
            // For client credentials flow (Managed Identity), don't require 'scp' or 'roles' claim
            RequireSignedTokens = true
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var principal = tokenHandler.ValidateToken(token, validationParameters, out var validatedToken);

        // Validate that token contains either user scopes or app roles
        if (!ValidateTokenClaims(principal))
        {
            throw new SecurityTokenValidationException("Token must contain either 'scp' (user delegation) or 'roles' (application permissions) claim");
        }

        return principal;
    }

    private bool ValidateTokenClaims(ClaimsPrincipal principal)
    {
        var acceptedScopes = _configuration.GetSection("AzureAd:AcceptedScopes").Get<string[]>() ?? Array.Empty<string>();
        var acceptedRoles = _configuration.GetSection("AzureAd:AcceptedAppRoles").Get<string[]>() ?? Array.Empty<string>();

        // Check for user delegation token (has 'scp' claim)
        var scopeClaim = principal.FindFirst("scp")?.Value ?? principal.FindFirst("http://schemas.microsoft.com/identity/claims/scope")?.Value;
        if (!string.IsNullOrEmpty(scopeClaim))
        {
            var scopes = scopeClaim.Split(' ');
            if (acceptedScopes.Any() && scopes.Any(s => acceptedScopes.Contains(s)))
            {
                return true;
            }
            // If no specific scopes configured, accept any valid user token
            if (!acceptedScopes.Any())
            {
                return true;
            }
        }

        // Check for application token with roles (Managed Identity or Service Principal)
        var rolesClaims = principal.FindAll("roles").Select(c => c.Value).ToList();
        if (rolesClaims.Any())
        {
            if (acceptedRoles.Any() && rolesClaims.Any(r => acceptedRoles.Contains(r)))
            {
                return true;
            }
            // If no specific roles configured but roles present, accept
            if (!acceptedRoles.Any())
            {
                return true;
            }
        }

        // If neither scopes nor roles are configured, accept the token (basic validation only)
        if (!acceptedScopes.Any() && !acceptedRoles.Any())
        {
            return true;
        }

        return false;
    }

    private async Task SendUnauthorizedResponse(Microsoft.Azure.Functions.Worker.Http.HttpRequestData req, string message)
    {
        var response = req.CreateResponse(HttpStatusCode.Unauthorized);
        response.Headers.Add("Content-Type", "application/json");
        await response.WriteStringAsync($"{{\"error\": \"Unauthorized\", \"message\": \"{message}\"}}");

        var invocationResult = req.FunctionContext.GetInvocationResult();
        invocationResult.Value = response;
    }
}
