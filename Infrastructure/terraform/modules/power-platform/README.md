# Power Platform Module

This module provisions Power Platform environments with optional managed environment features.

## Known Issues & Workarounds

### Managed Environment - makerOnboardingUrl API Error

**Issue:** The Power Platform Terraform provider (v3.8.0 - v3.9.1) marks `maker_onboarding_url` and `maker_onboarding_markdown` as required fields for the `powerplatform_managed_environment` resource. However, the Power Platform API rejects these fields with the error:

```
Could not find member 'makerOnboardingUrl' on object of type
'GovernanceConfigurationExtendedSettingsDefinition'
```

**Root Cause:** When manually creating managed environments through the Power Platform Admin Center, these fields are optional and can be configured later. The Terraform provider incorrectly includes them in the initial managed environment creation API call.

**Current Workaround:** The module uses the Power Platform CLI (`pac admin set-governance-config`) via a `null_resource` to enable managed environment features without sending the problematic fields.

**Location:** [main.tf](./main.tf#L78-L121)

### Switching Back to Native Terraform Resource

When a new version of the Power Platform provider fixes this issue:

1. **Comment out** the `null_resource` "managed_environment" (lines 97-121 in main.tf)
2. **Uncomment** the `powerplatform_managed_environment` resource (lines 79-94 in main.tf)
3. **Update** the dependency in `powerplatform_environment_settings` resource (line 179 in main.tf):
   - Comment: `null_resource.managed_environment`
   - Uncomment: `powerplatform_managed_environment.this`
4. **Update** the provider version constraint in:
   - [versions.tf](./versions.tf) (module level)
   - [../../versions.tf](../../versions.tf) (root level)
5. **Run** `terraform init -upgrade` to download the new provider version
6. **Run** `terraform plan` to verify the change

### Prerequisites for CLI Workaround

The workaround requires the Power Platform CLI (`pac`) to be installed and authenticated:

1. **Install PAC CLI:**
   ```powershell
   dotnet tool install --global Microsoft.PowerApps.CLI.Tool
   ```

2. **Authenticate:**
   ```powershell
   pac auth create --name dev --environment <environment-url>
   ```

## Usage

```hcl
module "powerplatform" {
  source = "./modules/power-platform"

  display_name               = "dev-myapp"
  description                = "Development environment"
  location                   = "europe"
  environment_type           = "Developer"
  owner_id                   = "user-guid"
  language_code              = 1033
  currency_code              = "EUR"

  # Managed Environment
  enable_managed_environment = true

  # Application User
  create_application_user    = true
  application_client_id      = "app-registration-client-id"
  security_roles             = ["System Administrator"]

  # NAT Gateway IP for firewall
  nat_gateway_public_ip      = "20.123.45.67"
}
```

## Resources Created

- `powerplatform_environment` - Power Platform environment
- `null_resource` - Enables managed environment via PAC CLI (workaround)
- `powerplatform_environment_application_admin` - Application user (optional)
- `powerplatform_environment_settings` - IP firewall settings (optional)

## Related Issues

- Track progress on the provider issue: [microsoft/terraform-provider-power-platform](https://github.com/microsoft/terraform-provider-power-platform/issues)

## Notes

- Solution checker mode and suppress validation emails are not currently configurable via PAC CLI
- Maker onboarding settings can be configured manually in the Power Platform Admin Center after environment creation
