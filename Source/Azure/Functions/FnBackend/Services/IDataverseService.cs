using Microsoft.Crm.Sdk.Messages;

namespace FnBackend.Services;

public interface IDataverseService
{
    /// <summary>
    /// Executes WhoAmI request using OAuth 2.0 On-Behalf-Of flow.
    /// Automatically extracts the Bearer token from the Authorization header in HttpContext.
    /// This is the recommended method for user-delegated operations.
    /// </summary>
    /// <returns>WhoAmI response containing user information</returns>
    Task<WhoAmIResponse> WhoAmIAsync();

    /// <summary>
    /// Executes WhoAmI request for Server-to-Server (S2S) authentication.
    /// Extracts the app registration client ID from the access token, finds the corresponding
    /// application user in Dataverse, and executes WhoAmI on behalf of that application user.
    /// </summary>
    /// <returns>WhoAmI response containing application user information</returns>
    Task<WhoAmIResponse> WhoAmIS2SAsync();
}
