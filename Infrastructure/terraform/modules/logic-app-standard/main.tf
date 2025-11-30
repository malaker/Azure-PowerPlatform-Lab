# ===================================
# Logic App Standard Module (Hybrid Pattern)
# ===================================
# This module creates Logic App Standard resources with full configuration.
# Workflows are deployed separately using:
# - VS Code Logic Apps extension
# - Azure CLI (az logicapp deployment)
# - GitHub Actions / Azure DevOps pipelines
#
# This hybrid approach ensures:
# - Terraform manages the Logic App resource and configuration
# - Workflows are managed independently (no Terraform drift)
# - Full VS Code integration for workflow development

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ===================================
# Logic App Naming with Shared Suffix
# ===================================
# Uses shared random suffix from main configuration to ensure
# consistent naming across all resources in the infrastructure

locals {
  # Use shared random suffix if provided, otherwise use the logic app name as-is
  logic_app_name_unique = var.random_suffix != "" ? "${var.logic_app_name}-${var.random_suffix}" : var.logic_app_name
}

# ===================================
# User-Assigned Managed Identity (Optional)
# ===================================
# When enabled, creates a user-assigned identity with pre-configured RBAC
# This ensures all permissions are propagated BEFORE Logic App is created

resource "azurerm_user_assigned_identity" "logicapp" {
  count = var.use_user_assigned_identity ? 1 : 0

  name                = "${local.logic_app_name_unique}-uami"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# RBAC for User-Assigned Identity (granted before Logic App creation)
resource "azurerm_role_assignment" "uami_storage_account_contributor" {
  count = var.use_user_assigned_identity && var.grant_storage_permissions ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_user_assigned_identity.logicapp[0].principal_id
}

resource "azurerm_role_assignment" "uami_storage_blob_owner" {
  count = var.use_user_assigned_identity && var.grant_storage_permissions ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.logicapp[0].principal_id
}

resource "azurerm_role_assignment" "uami_storage_queue_contributor" {
  count = var.use_user_assigned_identity && var.grant_storage_permissions ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.logicapp[0].principal_id
}

resource "azurerm_role_assignment" "uami_storage_table_contributor" {
  count = var.use_user_assigned_identity && var.grant_storage_permissions ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.logicapp[0].principal_id
}

resource "azurerm_role_assignment" "uami_storage_file_contributor" {
  count = var.use_user_assigned_identity && var.grant_storage_permissions ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_user_assigned_identity.logicapp[0].principal_id
}

resource "azurerm_role_assignment" "uami_keyvault_secrets_user" {
  count = var.use_user_assigned_identity && var.grant_key_vault_permissions ? 1 : 0

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.logicapp[0].principal_id
}

# Wait for RBAC propagation on user-assigned identity (before Logic App creation)
resource "time_sleep" "uami_rbac_propagation" {
  count = var.use_user_assigned_identity ? 1 : 0

  depends_on = [
    azurerm_role_assignment.uami_keyvault_secrets_user,
    azurerm_role_assignment.uami_storage_account_contributor,
    azurerm_role_assignment.uami_storage_blob_owner,
    azurerm_role_assignment.uami_storage_queue_contributor,
    azurerm_role_assignment.uami_storage_table_contributor,
    azurerm_role_assignment.uami_storage_file_contributor
  ]

  # Wait 5 minutes for full RBAC propagation before creating Logic App
  # This ensures the identity can create file shares immediately
  # Increased from 3m to 5m to prevent 409 conflicts during Logic App creation
  create_duration = "5m"
}

# ===================================
# File Share for Logic App Content
# ===================================
# Pre-create the file share to avoid timing issues with auto-creation
# When storage has network restrictions, auto-creation often fails
# File share naming: {logic_app_name}-content (lowercase, hyphens preserved)
# Azure file shares allow hyphens, and Logic Apps expects the name to match the Logic App name pattern

resource "azurerm_storage_share" "logicapp_content" {
  name               = lower("${local.logic_app_name_unique}-content")
  storage_account_id = var.storage_account_id
  quota              = 5120 # 5GB quota (minimum for Logic Apps)

  # Create after storage account is configured and RBAC is ready
  depends_on = [
    time_sleep.uami_rbac_propagation
  ]
}

# ===================================
# App Service Plan
# ===================================

resource "azurerm_service_plan" "this" {
  count = var.create_app_service_plan ? 1 : 0

  name                = var.app_service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  sku_name            = var.sku_name

  tags = var.tags
}

# ===================================
# Logic App Standard Resource
# ===================================

resource "azurerm_logic_app_standard" "this" {
  name                = local.logic_app_name_unique
  resource_group_name = var.resource_group_name
  location            = var.location
  app_service_plan_id = var.create_app_service_plan ? azurerm_service_plan.this[0].id : var.app_service_plan_id

  # Storage configuration - using managed identity authentication
  # Note: When using managed identity, we still provide access key for initial bootstrap
  # The managed identity settings in app_settings will take precedence for runtime operations
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_access_key

  # VNet integration for outbound traffic
  virtual_network_subnet_id = var.virtual_network_subnet_id

  # Managed Identity Configuration
  # Use BOTH system-assigned and user-assigned identities when user identity is enabled
  # - System-Assigned: Used for Key Vault references (works automatically)
  # - User-Assigned: Used for storage access with VNet restrictions (more reliable)
  # This hybrid approach avoids the need to configure keyVaultReferenceIdentity
  identity {
    type = var.use_user_assigned_identity ? "SystemAssigned, UserAssigned" : "SystemAssigned"
    identity_ids = var.use_user_assigned_identity ? [
      azurerm_user_assigned_identity.logicapp[0].id
    ] : null
  }

  # CRITICAL: Key Vault Reference Identity
  # This property tells Azure which identity to use for resolving Key Vault references
  # Without this, Key Vault references will fail with "MSINotEnabled" error
  # This is a RESOURCE-LEVEL property, not an app setting
  # Reference: https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references
  #key_vault_reference_identity_id = var.use_user_assigned_identity ? azurerm_user_assigned_identity.logicapp[0].id : null

  # Application settings
  app_settings = merge(
    {
      # ===================================
      # Core Runtime Settings
      # ===================================

      # Required for Logic App Standard
      # Microsoft changed the required value from "node" to "dotnet"
      # See: https://learn.microsoft.com/en-us/azure/logic-apps/create-single-tenant-workflows-azure-portal
      "FUNCTIONS_WORKER_RUNTIME" = "dotnet"

      # NOTE: FUNCTIONS_EXTENSION_VERSION is automatically managed by Azure for Logic Apps
      # Do not set it manually as it causes 409 Conflict errors

      # Enable .NET 8 in-process model (recommended for better performance)
      "FUNCTIONS_INPROC_NET8_ENABLED" = "1"

      # Node.js version - optional when using dotnet runtime, but kept for compatibility
      # with certain built-in connectors that may use Node.js internally
      # See: https://learn.microsoft.com/en-us/answers/questions/1346481/logic-apps-standard-node-version-upgrade-for-dotne
      "WEBSITE_NODE_DEFAULT_VERSION" = "~20"

      # ===================================
      # Extension Bundle Configuration
      # ===================================
      # NOTE: Extension bundle settings are automatically managed by Azure for Logic Apps Standard
      # AzureFunctionsJobHost__extensionBundle__id = "Microsoft.Azure.Functions.ExtensionBundle.Workflows"
      # AzureFunctionsJobHost__extensionBundle__version = "[1.*, 2.0.0)"
      # Do not set these manually as they cause 409 Conflict errors

      # ===================================
      # Storage Configuration with Managed Identity
      # ===================================

      # Managed Identity authentication for storage (more secure than access keys)
      # The runtime uses managed identity for data plane operations
      "AzureWebJobsStorage__accountName"     = var.storage_account_name
      "AzureWebJobsStorage__credential"      = "managedidentity"
      "AzureWebJobsStorage__blobServiceUri"  = "https://${var.storage_account_name}.blob.core.windows.net"
      "AzureWebJobsStorage__queueServiceUri" = "https://${var.storage_account_name}.queue.core.windows.net"
      "AzureWebJobsStorage__tableServiceUri" = "https://${var.storage_account_name}.table.core.windows.net"
      "AzureWebJobsSecretStorageType"        = "files"
      # For user-assigned identity, specify the resource ID and client ID
      "AzureWebJobsStorage__managedIdentityResourceId" = var.use_user_assigned_identity ? azurerm_user_assigned_identity.logicapp[0].id : null
      "AzureWebJobsStorage__clientId"                  = var.use_user_assigned_identity ? azurerm_user_assigned_identity.logicapp[0].client_id : null

      # Secrets storage configuration - use the same storage as AzureWebJobsStorage
      # When using managed identity for AzureWebJobsStorage, secrets are automatically stored there
      # No additional configuration needed - the runtime uses AzureWebJobsStorage for secrets

      # File share authentication - also uses managed identity
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__accountName"             = var.storage_account_name
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__credential"              = "managedidentity"
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__managedIdentityResourceId" = var.use_user_assigned_identity ? azurerm_user_assigned_identity.logicapp[0].id : null
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__clientId"                = var.use_user_assigned_identity ? azurerm_user_assigned_identity.logicapp[0].client_id : null

      # VNet content access - enables runtime to access storage via VNet
      "WEBSITE_CONTENTOVERVNET" = var.enable_vnet_content_access ? "1" : "0"

      # Pre-created file share name - ensures Logic App uses the correct share
      # We pre-create the share to avoid timing issues with auto-creation
      #
      #"WEBSITE_CONTENTSHARE" = azurerm_storage_share.logicapp_content.name

      # ===================================
      # Monitoring
      # ===================================

      # Application Insights (if provided)
      "APPINSIGHTS_INSTRUMENTATIONKEY" = var.app_insights_instrumentation_key
    },
    var.app_settings
  )

  # Site configuration
  site_config {
    # Enable VNet route all for outbound traffic
    vnet_route_all_enabled = var.vnet_route_all_enabled

    # Minimum TLS version
    min_tls_version = var.min_tls_version

    # Always On
    always_on = var.always_on

    # Inbound IP restrictions
    # Supports both subnet-based rules and service tag rules
    # - Subnet-based: Set virtual_network_subnet_id (for VNet-integrated resources)
    # - Service tag: Set service_tag (e.g., "PowerPlatformInfra" for Dataverse triggers)
    dynamic "ip_restriction" {
      for_each = var.ip_restrictions
      content {
        name                      = ip_restriction.value.name
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
        service_tag               = ip_restriction.value.service_tag
        priority                  = ip_restriction.value.priority
        action                    = ip_restriction.value.action
      }
    }
  }

  tags = var.tags

  # Lifecycle configuration to prevent 409 conflicts during updates
  lifecycle {
    ignore_changes = [
      # Ignore changes to these settings as Azure manages them automatically
      app_settings["FUNCTIONS_EXTENSION_VERSION"],
      app_settings["AzureFunctionsJobHost__extensionBundle__id"],
      app_settings["AzureFunctionsJobHost__extensionBundle__version"],
      app_settings["WEBSITE_CONTENTSHARE"]
    ]
  }

  # Critical: Ensure file share exists and RBAC is ready before creating Logic App
  # This ensures the Logic App starts successfully with all prerequisites in place
  depends_on = [
    azurerm_service_plan.this,
    azurerm_storage_share.logicapp_content,
    time_sleep.uami_rbac_propagation
  ]
}

# ===================================
# RBAC: Key Vault Access (System-Assigned Identity)
# ===================================
# Grant System-Assigned Identity access to Key Vault for Key Vault references
# This is needed when using hybrid identity model (both system and user-assigned)
# System-Assigned Identity is used for Key Vault references automatically

resource "azurerm_role_assignment" "keyvault_secrets_user" {
  for_each = var.grant_key_vault_permissions ? toset(["enabled"]) : toset([])

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_logic_app_standard.this.identity[0].principal_id
}

# ===================================
# RBAC: Storage Account Access (System-Assigned Identity Only)
# ===================================
# Minimum required roles for Logic Apps Standard managed identity:
# Reference: https://learn.microsoft.com/en-us/azure/logic-apps/set-up-zone-redundancy-availability-zones
# These roles are only assigned when using system-assigned identity
# For user-assigned identity, roles are assigned before Logic App creation

# Storage Account Contributor - Required for management operations (creating file shares, containers)
resource "azurerm_role_assignment" "storage_account_contributor" {
  for_each = !var.use_user_assigned_identity && var.grant_storage_permissions ? toset(["enabled"]) : toset([])

  scope                = var.storage_account_id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_logic_app_standard.this.identity[0].principal_id
}

# Storage Blob Data Owner - Required for full blob access including ACLs and metadata
resource "azurerm_role_assignment" "storage_blob_owner" {
  for_each = !var.use_user_assigned_identity && var.grant_storage_permissions ? toset(["enabled"]) : toset([])

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_logic_app_standard.this.identity[0].principal_id
}

# Storage Queue Data Contributor - Required for queue operations
resource "azurerm_role_assignment" "storage_queue_contributor" {
  for_each = !var.use_user_assigned_identity && var.grant_storage_permissions ? toset(["enabled"]) : toset([])

  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_logic_app_standard.this.identity[0].principal_id
}

# Storage Table Data Contributor - Required for table operations
resource "azurerm_role_assignment" "storage_table_contributor" {
  for_each = !var.use_user_assigned_identity && var.grant_storage_permissions ? toset(["enabled"]) : toset([])

  scope                = var.storage_account_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_logic_app_standard.this.identity[0].principal_id
}

# Storage File Data Privileged Contributor - Required for file share operations
resource "azurerm_role_assignment" "storage_file_contributor" {
  for_each = !var.use_user_assigned_identity && var.grant_storage_permissions ? toset(["enabled"]) : toset([])

  scope                = var.storage_account_id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_logic_app_standard.this.identity[0].principal_id
}

# ===================================
# RBAC Propagation Wait (System-Assigned Identity Only)
# ===================================
# For system-assigned identity, we wait AFTER Logic App creation
# For user-assigned identity, we wait BEFORE Logic App creation (handled above)

resource "time_sleep" "rbac_propagation" {
  for_each = !var.use_user_assigned_identity && (var.grant_key_vault_permissions || var.grant_storage_permissions) ? toset(["enabled"]) : toset([])

  depends_on = [
    azurerm_role_assignment.keyvault_secrets_user,
    azurerm_role_assignment.storage_account_contributor,
    azurerm_role_assignment.storage_blob_owner,
    azurerm_role_assignment.storage_queue_contributor,
    azurerm_role_assignment.storage_table_contributor,
    azurerm_role_assignment.storage_file_contributor
  ]

  # Increased to 2 minutes to allow for Azure AD RBAC propagation
  # Storage network rules + VNet integration require fully propagated permissions
  # Note: Even with this wait, system-assigned identity may still have timing issues
  # Consider using user-assigned identity (use_user_assigned_identity = true) instead
  create_duration = "2m"
}
