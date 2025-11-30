using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;


namespace Kb.Plugin.Services
{
    public class AzKeyVaultService
    {
        private readonly IManagedIdentityService _managedIdentityService;

        public AzKeyVaultService(IManagedIdentityService managedIdentityService)
        {
            _managedIdentityService = managedIdentityService;
        }

        public string GetSecret(string keyVaultName, string secretName)
        {
            var scopes = new List<string> { "https://vault.azure.net/.default" };

            string accessToken = _managedIdentityService.AcquireToken(scopes);

            using (var client = new HttpClient())
            {
                var secretUrl = $"https://{keyVaultName}.vault.azure.net/secrets/{secretName}?api-version=7.4";

                var request = new HttpRequestMessage(HttpMethod.Get, new Uri(secretUrl));

                request.Headers.Authorization= new AuthenticationHeaderValue("Bearer", accessToken);

                using (var response = client.SendAsync(request).Result)
                {
                    string secretValue = response.Content.ReadAsStringAsync().Result;

                    return secretValue;
                }
            }
        }
    }
}
