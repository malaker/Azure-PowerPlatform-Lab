# ===================================
# NOTE: Application Registration for Power Platform
# ===================================

# The managed_identity_id parameter in the solution packing refers to the
# Application (client) ID of your Power Platform service app registration.
# This is already created in the app_registrations module and can be referenced
# as: module.app_registrations["power-platform-svc"].client_id
#
# The app registration is used by Dataverse plugins to authenticate.

# ===================================
# Federated Identity Credentials for Power Platform
# ===================================

# Create federated identity credentials for Power Platform Dataverse plugin authentication
# These are created AFTER the Power Platform environments are provisioned so we have the environment IDs
resource "azuread_application_federated_identity_credential" "powerplatform_plugins" {
  for_each = var.powerplatform_federated_credential_issuer != "" && var.powerplatform_federated_credential_certificate_subject != "" ? local.powerplatform_federated_credentials : {}

  application_id = module.app_registrations["power-platform-svc"].application_object_id
  display_name   = each.value.display_name
  description    = each.value.description
  audiences      = each.value.audiences
  issuer         = each.value.issuer
  subject        = each.value.subject

  depends_on = [module.powerplatform]
}

# ===================================
# Power Platform Environments
# ===================================

# Create Power Platform environments with application users
module "powerplatform" {
  source = "./modules/power-platform"

  for_each = local.power_platform_configs

  display_name               = each.value.display_name
  description                = each.value.description
  location                   = each.value.location
  environment_type           = each.value.environment_type
  owner_id                   = each.value.owner_id
  release_cycle              = each.value.release_cycle
  language_code              = each.value.language_code
  currency_code              = each.value.currency_code
  security_group_id          = each.value.security_group_id
  create_application_user      = each.value.create_app_user
  application_client_id        = each.value.application_client_id
  additional_application_users = each.value.additional_application_users
  security_roles               = each.value.security_roles
  enable_managed_environment   = each.value.enable_managed_environment

  # Enterprise policy for subnet delegation (optional)
  enable_enterprise_policy = var.enable_powerplatform_subnet_delegation
  enterprise_policy_id     = var.enable_powerplatform_subnet_delegation ? module.powerplatform_enterprise_policy[0].id : null

  # Pass NAT Gateway public IP to include in IP firewall allowlist
  # This ensures Azure services in the VNet can communicate with Power Platform
  nat_gateway_public_ip = module.network.nat_public_ip_address

  # ===================================
  # Solution Import Configuration
  # ===================================

  # Option 1: Import pre-packaged solutions only
  # Uncomment and customize the solutions list below:
  #
  # solutions = [
  #   {
  #     solution_name    = "common-components"
  #     solution_file    = "${path.root}/../Solutions/CommonComponents_1_0_0_0.zip"
  #     settings_file    = "${path.root}/../Solutions/CommonComponents_settings.json"
  #     activate_plugins = true
  #   }
  # ]

  # Option 2: Pack custom solution with token replacement + import
  # Using the Power Platform app registration client ID for Dataverse plugin authentication
  #
  # IMPORTANT: Two-stage deployment required for custom solution packing:
  # 1. First apply: Packs the solution (creates the ZIP file)
  # 2. Second apply: Imports the packed solution to Power Platform
  #
  # This is necessary because Terraform validates file paths during planning,
  # but the ZIP file doesn't exist until the null_resource runs.
  solution_folder        = "${path.root}/../../Source/PowerPlatform/Solutions/pplab01/src"
  managed_identity_id    = module.app_registrations["power-platform-svc"].client_id
  tenant_id              = data.azurerm_client_config.current.tenant_id
  solution_pack_zip_path = "${path.root}/../../Source/PowerPlatform/Solutions/pplab01/packed/IntegrationGuideSolution.zip"

  # Solutions will be imported only if the packed file exists
  # Use fileexists() to prevent errors on first apply
  solutions = fileexists("${path.root}/../../Source/PowerPlatform/Solutions/pplab01/packed/IntegrationGuideSolution.zip") ? [
    {
      solution_name    = "integration-guide-solution"
      solution_file    = "${path.root}/../../Source/PowerPlatform/Solutions/pplab01/packed/IntegrationGuideSolution.zip"
      settings_file    = ""
      activate_plugins = true
    }
  ] : []

  depends_on = [
    module.app_registrations,
    module.network,                        # Wait for NAT Gateway to be created for IP firewall configuration
    module.powerplatform_enterprise_policy # Wait for enterprise policy if enabled
  ]
}

# ===================================
# Power Platform Subnet Delegation (Optional)
# ===================================

# NOTE: Power Platform subnet delegation is now configured directly on the
# existing subnet-powerplatform in the primary VNet (West Europe).
# The delegation is controlled by enable_powerplatform_subnet_delegation variable
# and applied via the network module's enable_powerplatform_delegation parameter.
# This approach reuses existing infrastructure instead of creating a separate VNet.

# ===================================
# Power Platform Subnet Delegation Wait
# ===================================

# Wait for subnet delegation to be fully applied before creating enterprise policy
# This prevents race conditions where the enterprise policy is created before
# the subnet delegation is recognized by Azure
resource "time_sleep" "wait_for_delegation" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  create_duration = "30s"

  depends_on = [module.network, azurerm_subnet.northeurope_powerplatform]
}

# ===================================
# Power Platform Enterprise Policy (Optional)
# ===================================

# Enterprise policy for subnet delegation and VNet integration
# This Azure resource enables Power Platform to inject into the delegated subnet
module "powerplatform_enterprise_policy" {
  source = "./modules/power-platform-enterprise-policy"

  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name              = "${var.environment}-${var.project_name}-enterprise-policy"
  display_name      = "${var.environment}-${var.project_name}-enterprise-policy"
  location          = "europe"  # Enterprise policies use region groups, not specific Azure regions
  resource_group_id = module.resource_groups["network"].id

  # IMPORTANT: Power Platform Enterprise Policies require at least 2 subnets in paired Azure regions
  # for business continuity and disaster recovery.
  # West Europe (primary) + North Europe (paired region)
  subnets = [
    {
      id   = module.network.subnet_powerplatform_id
      name = module.network.subnet_powerplatform_name
    },
    {
      id   = azurerm_subnet.northeurope_powerplatform[0].id
      name = azurerm_subnet.northeurope_powerplatform[0].name
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Component = "Enterprise Policy"
      Purpose   = "Power Platform VNet Integration"
    }
  )

  depends_on = [time_sleep.wait_for_delegation]
}
