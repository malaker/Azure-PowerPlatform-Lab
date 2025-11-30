# ===================================
# Data Sources
# ===================================

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Get current user/service principal details
data "azuread_client_config" "current" {}

# ===================================
# Random ID for Unique Resource Names
# ===================================

# Generate a random ID for globally unique resource names
# This ensures Key Vault and other globally unique resources don't conflict
# when the code is shared or open-sourced
resource "random_id" "unique_suffix" {
  byte_length = 4

  keepers = {
    # Regenerate when project or environment changes
    project     = var.project_name
    environment = var.environment
  }
}

# ===================================
# Resource Groups
# ===================================

# Create resource groups for different services
module "resource_groups" {
  source = "./modules/resource-groups"

  for_each = local.resource_group_configs

  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags
}

# Resource group for North Europe network (paired region for enterprise policy)
module "resource_group_network_northeurope" {
  source = "./modules/resource-groups"

  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name     = "rg-${var.environment}-network-northeurope"
  location = local.current_env_config.backup_location
  tags = merge(
    local.common_tags,
    {
      Purpose = "Network resources for North Europe (paired region)"
      Region  = "northeurope"
    }
  )
}

# ===================================
# Key Vault
# ===================================

# Create Key Vault for secrets management in dedicated resource group
module "key_vault" {
  source = "./modules/key-vaults"

  key_vault_name                = local.key_vault_name
  resource_group_name           = module.resource_groups["keyvaults"].name
  location                      = module.resource_groups["keyvaults"].location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = coalesce(var.key_vault_sku, local.current_env_config.key_vault_sku)
  soft_delete_retention_days    = coalesce(var.soft_delete_retention_days, local.current_env_config.soft_delete_retention_days)
  enable_purge_protection       = coalesce(var.enable_purge_protection, local.current_env_config.enable_purge_protection)
  enable_rbac_authorization     = true
  public_network_access_enabled = local.current_env_config.public_network_access
  allowed_ip_addresses          = var.allowed_ip_addresses

  # Allow access from all Azure service subnets that need Key Vault access
  # - Power Platform: For Dataverse connections and custom connectors
  # - Logic Apps: Required for Key Vault references to work with VNet integration
  # - Functions: For application configuration and secrets
  # - APIM: For backend authentication and API policies
  allowed_subnet_ids = concat(
    [module.network.subnet_powerplatform_id],
    [module.network.subnet_logicapps_id],
    [module.network.subnet_fn_id],
    var.enable_api_management ? [module.network.subnet_apim_id] : [],
    var.enable_powerplatform_subnet_delegation ? [azurerm_subnet.northeurope_powerplatform[0].id] : []
  )

  # Grant current user/service principal access
  admin_object_ids = [data.azuread_client_config.current.object_id]

  tags = local.key_vault_tags

  depends_on = [module.resource_groups, module.network]
}

# ===================================
# RBAC Propagation Wait
# ===================================

# Wait for RBAC permissions to propagate
resource "time_sleep" "rbac_propagation" {
  depends_on = [module.key_vault]

  create_duration = "30s"
}

# ===================================
# App Registrations
# ===================================

# Create app registrations with environment-specific configuration
module "app_registrations" {
  source = "./modules/app-registrations"

  for_each = local.app_registration_configs

  display_name                 = each.value.display_name
  description                  = each.value.description
  sign_in_audience             = each.value.sign_in_audience
  redirect_uris                = each.value.redirect_uris
  required_resource_access     = each.value.required_resource_access
  secret_expiration            = each.value.secret_expiration
  key_vault_id                 = module.key_vault.key_vault_id
  store_secret_in_keyvault     = true
  expose_api                   = each.value.expose_api
  api_scope_name               = each.value.api_scope_name
  api_scope_description        = each.value.api_scope_description
  expose_app_roles             = each.value.expose_app_roles
  app_roles                    = each.value.app_roles

  depends_on = [time_sleep.rbac_propagation]
}

# ===================================
# App Registration API Permissions
# ===================================

# Add required resource access to power-platform-svc for az-function-backend
# This configures the API permissions programmatically using Terraform data source
resource "azuread_application_api_access" "powerplatform_to_function" {
  application_id = module.app_registrations["power-platform-svc"].application_object_id
  api_client_id  = module.app_registrations["az-function-backend"].client_id

  # Delegated permission (OAuth2 scope) for on-behalf-of flow
  scope_ids = [
    module.app_registrations["az-function-backend"].api_scope_id
  ]

  # Application permission (App Role) for client credentials flow
  role_ids = [
    module.app_registrations["az-function-backend"].app_role_ids["API.Access.All"]
  ]

  depends_on = [module.app_registrations]
}

# Grant admin consent for delegated permissions (OAuth2 scope)
resource "azuread_service_principal_delegated_permission_grant" "powerplatform_to_function" {
  service_principal_object_id          = module.app_registrations["power-platform-svc"].service_principal_id
  resource_service_principal_object_id = module.app_registrations["az-function-backend"].service_principal_id
  claim_values                         = [module.app_registrations["az-function-backend"].api_scope_name]

  depends_on = [azuread_application_api_access.powerplatform_to_function]
}

# Grant app role assignment for application permissions
resource "azuread_app_role_assignment" "powerplatform_to_function" {
  app_role_id         = module.app_registrations["az-function-backend"].app_role_ids["API.Access.All"]
  principal_object_id = module.app_registrations["power-platform-svc"].service_principal_id
  resource_object_id  = module.app_registrations["az-function-backend"].service_principal_id

  depends_on = [azuread_application_api_access.powerplatform_to_function]
}

# ===================================
# Key Vault RBAC for Power Platform Service Principal
# ===================================

# Grant Key Vault Secrets User role to power-platform-svc service principal
# This allows Dataverse plugins to read secrets from Key Vault using federated credentials
resource "azurerm_role_assignment" "powerplatform_svc_keyvault_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_registrations["power-platform-svc"].service_principal_id

  depends_on = [module.key_vault, module.app_registrations]
}

# Additional wait for Key Vault RBAC to propagate
resource "time_sleep" "keyvault_rbac_propagation" {
  depends_on = [azurerm_role_assignment.powerplatform_svc_keyvault_secrets_user]

  create_duration = "30s"
}

# ===================================
# Log Analytics Workspace
# ===================================

# Shared Log Analytics Workspace for monitoring and diagnostics
module "log_analytics" {
  source = "./modules/log-analytics"

  workspace_name      = "${var.environment}-${var.project_name}-law-${local.region_short}"
  resource_group_name = module.resource_groups["functions"].name
  location            = module.resource_groups["functions"].location
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 90 : 30

  tags = merge(
    local.common_tags,
    {
      Component = "Monitoring"
      Purpose   = "Centralized logging and monitoring for Application Insights"
    }
  )

  depends_on = [module.resource_groups]
}
