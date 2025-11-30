using Kb.Plugin.Services;
using Microsoft.Xrm.Sdk;
using System;

namespace Kb.Plugin
{
    public class GenericHttpClientDemoPlugin : PluginBase
    {
        public GenericHttpClientDemoPlugin()
            : base(typeof(GenericHttpClientDemoPlugin))
        {
        }

        protected override void ExecuteDataversePlugin(ILocalPluginContext localPluginContext)
        {
            if (localPluginContext == null)
            {
                throw new ArgumentNullException(nameof(localPluginContext));
            }

            var context = localPluginContext.PluginExecutionContext;

            string scope = !context.InputParameters.ContainsKey("Scope") ? throw new InvalidPluginExecutionException("Missing parameter Scope") : context.InputParameters["Scope"].ToString();

            string baseUri = !context.InputParameters.ContainsKey("BaseUri") ? throw new InvalidPluginExecutionException("Missing parameter BaseUri") : context.InputParameters["BaseUri"].ToString();

            string relativeUri = !context.InputParameters.ContainsKey("RelativeUri") ? throw new InvalidPluginExecutionException("Missing parameter RelativeUri") : context.InputParameters["RelativeUri"].ToString();

            string httpMethod = !context.InputParameters.ContainsKey("HttpMethod") ? throw new InvalidPluginExecutionException("Missing parameter HttpMethod") : context.InputParameters["HttpMethod"].ToString();

            IManagedIdentityService managedIdentityService = (IManagedIdentityService)localPluginContext.ServiceProvider.GetService(typeof(IManagedIdentityService));

            GenericHttpClient genericHttpClient = new GenericHttpClient(managedIdentityService, localPluginContext.TracingService);

            if (string.Equals("get", httpMethod, StringComparison.InvariantCultureIgnoreCase))
            {
                (string response, int statusCode) = genericHttpClient.SendGet(scope, baseUri, relativeUri);

                context.OutputParameters["Response"] = response;
                context.OutputParameters["StatusCode"] = statusCode;
            }
            else
            {
                throw new InvalidPluginExecutionException("Requested http method not supported");
            }


        }
    }
}
