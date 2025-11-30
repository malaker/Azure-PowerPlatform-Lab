using Kb.Plugin.Services;
using Microsoft.Xrm.Sdk;
using System;

namespace Kb.Plugin
{
    public class AzKeyVaultDemoPlugin : PluginBase
    {
        public AzKeyVaultDemoPlugin()
            : base(typeof(AzKeyVaultDemoPlugin))
        {
        }

        protected override void ExecuteDataversePlugin(ILocalPluginContext localPluginContext)
        {
            if (localPluginContext == null)
            {
                throw new ArgumentNullException(nameof(localPluginContext));
            }

            var context = localPluginContext.PluginExecutionContext;

            string azKeyVaultName = !context.InputParameters.ContainsKey("AzKeyVaultName") ? throw new InvalidPluginExecutionException("Missing parameter AzKeyVaultName") : context.InputParameters["AzKeyVaultName"].ToString();

            string secretName = !context.InputParameters.ContainsKey("SecretName") ? throw new InvalidPluginExecutionException("Missing parameter SecretName") : context.InputParameters["SecretName"].ToString();

            IManagedIdentityService managedIdentityService = (IManagedIdentityService)localPluginContext.ServiceProvider.GetService(typeof(IManagedIdentityService));

            AzKeyVaultService vaultService = new AzKeyVaultService(managedIdentityService);

            string value = vaultService.GetSecret(azKeyVaultName, secretName);

            if (!string.IsNullOrEmpty(value))
            {
                localPluginContext.Trace("Secret succesfully retrieved from vault");
            }

        }
    }
}
