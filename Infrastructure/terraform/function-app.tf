# ===================================
# Storage Accounts
# ===================================

# Storage account for Function App
module "storage_account_functions" {
  source = "./modules/storage-account"

  # Format: {env}{project_abbr}func{region}{random} (max 24 chars)
  # Example: devpplab01funcweua1b2 (22 chars)
  # Random suffix ensures global uniqueness for open-source sharing
  storage_account_name     = "${local.storage_account_name_prefix}func${local.region_short}${local.random_suffix}"
  resource_group_name      = module.resource_groups["functions"].name
  location                 = module.resource_groups["functions"].location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  public_network_access_enabled   = true

  # Network rules - allow access from VNet subnets
  enable_network_rules    = true
  default_network_action  = "Deny"
  network_bypass          = ["AzureServices", "Logging", "Metrics"]

  # Allow access from all relevant subnets
  allowed_subnet_ids = concat(
    # Function App subnet (required for runtime access)
    [module.network.subnet_fn_id],
    # APIM subnet (if APIM needs to access storage)
    [module.network.subnet_apim_id],
    # Power Platform subnet in West Europe
    [module.network.subnet_powerplatform_id],
    # Power Platform subnet in North Europe (when delegation is enabled)
    var.enable_powerplatform_subnet_delegation ? [azurerm_subnet.northeurope_powerplatform[0].id] : []
  )

  # Enable blob and queue properties for Function Apps
  enable_blob_properties  = true
  enable_queue_properties = true

  # Soft delete retention (environment-specific)
  blob_soft_delete_retention_days      = var.environment == "prod" ? 30 : 7
  container_soft_delete_retention_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.common_tags,
    {
      Component = "Storage"
      Purpose   = "Function App storage for code, logs, and runtime data"
    }
  )

  depends_on = [module.resource_groups, module.network]
}

# ===================================
# Function App (Flex Consumption)
# ===================================

# Create Function App with VNet integration and inbound restrictions
module "function_app" {
  source = "./modules/function-app-flex"

  function_app_name      = "${var.environment}-${var.project_name}-func-${local.region_short}"
  app_insights_name      = "${var.environment}-${var.project_name}-ai-${local.region_short}"
  resource_group_name    = module.resource_groups["functions"].name
  location               = module.resource_groups["functions"].location

  # Random suffix for globally unique resource names
  # Ensures consistency with other resources (storage, key vault, etc.)
  random_suffix = local.random_suffix

  # Use dedicated storage account
  storage_account_id    = module.storage_account_functions.storage_account_id
  storage_account_name  = module.storage_account_functions.storage_account_name
  storage_blob_endpoint = module.storage_account_functions.primary_blob_endpoint

  # Log Analytics Workspace for Application Insights
  log_analytics_workspace_id = module.log_analytics.workspace_id

  # VNet integration - outbound traffic goes through subnet-functions
  subnet_id = module.network.subnet_fn_id

  # Inbound access restrictions
  # Conditional logic based on APIM deployment:
  # - When APIM is enabled (enable_api_management = true):
  #   Traffic flows: Power Platform -> APIM -> Function App
  #   Only APIM subnet is allowed (more restrictive security)
  # - When APIM is disabled (enable_api_management = false):
  #   Traffic flows: Power Platform -> Function App (direct)
  #   Power Platform subnets are allowed (both West Europe and North Europe)
  allowed_subnet_ids = var.enable_api_management ? [
    # APIM is enabled: only allow traffic from APIM subnet
    module.network.subnet_apim_id
  ] : concat(
    # APIM is disabled: allow direct Power Platform access from both regions
    [
      module.network.subnet_apim_id,
      module.network.subnet_powerplatform_id
    ],
    var.enable_powerplatform_subnet_delegation ? [azurerm_subnet.northeurope_powerplatform[0].id] : []
  )

  # Optional: Configure runtime (default is dotnet-isolated)
  runtime = "dotnet-isolated"

  # Application settings with Dataverse configuration
  # Using Key Vault references for secure secret access
  app_settings = merge(
    {
      # Dataverse configuration for calling Power Platform APIs
      "Dataverse__Url" = length(module.powerplatform) > 0 ? module.powerplatform[keys(module.powerplatform)[0]].environment_url : ""

      # App Registration settings using Key Vault references
      # Format: @Microsoft.KeyVault(SecretUri=https://<keyvault-name>.vault.azure.net/secrets/<secret-name>/<version>)
      "Dataverse__AppRegistration__ClientId"     = "@Microsoft.KeyVault(SecretUri=${module.key_vault.key_vault_uri}secrets/${module.app_registrations["az-function-backend"].client_id_name}/)"
      "Dataverse__AppRegistration__ClientSecret" = "@Microsoft.KeyVault(SecretUri=${module.key_vault.key_vault_uri}secrets/${module.app_registrations["az-function-backend"].secret_key_name}/)"
      "Dataverse__AppRegistration__TenantId"     = data.azurerm_client_config.current.tenant_id
    },
    var.additional_function_app_settings
  )

  tags = merge(
    local.common_tags,
    {
      Component = "Functions"
      Purpose   = "Serverless compute for API integrations"
    }
  )

  depends_on = [
    module.resource_groups,
    module.network,
    module.storage_account_functions,
    module.log_analytics,
    module.key_vault,
    module.app_registrations,
    time_sleep.keyvault_rbac_propagation
  ]
}

# ===================================
# Function App RBAC for Key Vault
# ===================================

# Grant Function App managed identity Key Vault Secrets User role
# This allows the Function App to read secrets referenced in application settings via Key Vault references
resource "azurerm_role_assignment" "function_app_keyvault_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function_app.function_app_principal_id

  depends_on = [module.function_app, module.key_vault]
}

# ===================================
# Function App RBAC for Storage Account
# ===================================

# Grant Function App managed identity Storage Blob Data Contributor role
# This is required when using managed identity for storage account access instead of connection strings
# Allows the Function App to read/write blobs for function code, logs, and runtime data
resource "azurerm_role_assignment" "function_app_storage_blob_contributor" {
  scope                = module.storage_account_functions.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.function_app.function_app_principal_id

  depends_on = [module.function_app, module.storage_account_functions]
}

# Grant Function App managed identity Storage Queue Data Contributor role
# Required for queue-based triggers and bindings
resource "azurerm_role_assignment" "function_app_storage_queue_contributor" {
  scope                = module.storage_account_functions.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = module.function_app.function_app_principal_id

  depends_on = [module.function_app, module.storage_account_functions]
}

# Grant Function App managed identity Storage Table Data Contributor role
# Required for table storage operations
resource "azurerm_role_assignment" "function_app_storage_table_contributor" {
  scope                = module.storage_account_functions.storage_account_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = module.function_app.function_app_principal_id

  depends_on = [module.function_app, module.storage_account_functions]
}

# Wait for RBAC permissions to propagate before deploying function code
resource "time_sleep" "function_storage_rbac_propagation" {
  depends_on = [
    azurerm_role_assignment.function_app_storage_blob_contributor,
    azurerm_role_assignment.function_app_storage_queue_contributor,
    azurerm_role_assignment.function_app_storage_table_contributor
  ]

  create_duration = "30s"
}
