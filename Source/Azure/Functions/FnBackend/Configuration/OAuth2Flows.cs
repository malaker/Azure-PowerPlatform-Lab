using Microsoft.OpenApi.Models;

namespace FnBackend.Configuration;

/// <summary>
/// OAuth2 flows configuration for OpenAPI/Swagger documentation
/// </summary>
public class OAuth2Flows : OpenApiOAuthFlows
{
    public OAuth2Flows()
    {
        Implicit = new OpenApiOAuthFlow
        {
            AuthorizationUrl = new Uri("https://login.microsoftonline.com/common/oauth2/v2.0/authorize"),
            Scopes = new Dictionary<string, string>
            {
                { "api://your-client-id/user_impersonation", "Access the API as a user" }
            }
        };
    }
}
