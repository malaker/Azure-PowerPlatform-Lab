using Microsoft.Xrm.Sdk;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;

namespace Kb.Plugin.Services
{
    public class GenericHttpClient
    {
        private readonly IManagedIdentityService _managedIdentityService;
        private readonly ITracingService _tracingService;

        public GenericHttpClient(IManagedIdentityService managedIdentityService, ITracingService tracingService)
        {
            _managedIdentityService = managedIdentityService;
            _tracingService = tracingService;
        }

        public (string, int) SendGet(string scope, string baseUri, string relativeUri)
        {
            string accessToken = _managedIdentityService.AcquireToken(new List<string>() { scope });

            if (!string.IsNullOrEmpty(accessToken))
            {
                _tracingService.Trace("Token issued");
                _tracingService.Trace(accessToken);
            }


            using (var client = new HttpClient())
            {

                client.BaseAddress = new Uri(baseUri);

                var request = new HttpRequestMessage(HttpMethod.Get, relativeUri);

                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

                if (!request.Headers.Contains("Authorization"))
                {
                    request.Headers.Add("Authorization", "Bearer " + accessToken);
                }

                _tracingService.Trace("Sending request...");
                try
                {
                    using (var response = client.SendAsync(request).Result)
                    {
                        _tracingService.Trace("Request sent, processing response...");

                        if (response.IsSuccessStatusCode)
                        {
                            _tracingService.Trace("Response has successfull status code");
                        }
                        else
                        {
                            _tracingService.Trace($"StatusCode:{response.StatusCode},ReasonPhrase:{response.ReasonPhrase}");
                        }

                        string responseString = response.Content.ReadAsStringAsync().Result;

                        return (responseString, (int)response.StatusCode);
                    }
                }
                catch (Exception ex)
                {
                    _tracingService.Trace(JsonConvert.SerializeObject(ex));

                    throw;
                }
            }
        }
    }
}
