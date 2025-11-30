# ===================================
# Azure Data Factory Module
# ===================================
# This module creates Azure Data Factory with VNet integration for secure connectivity.
#
# Network Architecture:
# - Managed VNet for Data Factory runtime (Azure Integration Runtime)
# - Managed Private Endpoints to Storage, Key Vault, and other Azure services
# - Outbound traffic routes through NAT Gateway for whitelisting in Power Platform
#
# Use Cases:
# - ETL/ELT pipelines between Power Platform and Azure services
# - Data ingestion from external sources to Dataverse
# - Scheduled data synchronization workflows

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ===================================
# Data Factory Naming with Shared Suffix
# ===================================

locals {
  # Use shared random suffix if provided, otherwise use the data factory name as-is
  # Data Factory names must be globally unique (3-63 chars, alphanumeric and hyphens)
  data_factory_name_unique = var.random_suffix != "" ? "${var.data_factory_name}-${var.random_suffix}" : var.data_factory_name
}

# ===================================
# Azure Data Factory
# ===================================

resource "azurerm_data_factory" "this" {
  name                = local.data_factory_name_unique
  location            = var.location
  resource_group_name = var.resource_group_name

  # Managed Virtual Network configuration
  # This creates an isolated network for Data Factory Integration Runtime
  # All outbound traffic from pipelines goes through this managed VNet
  managed_virtual_network_enabled = var.enable_managed_vnet

  # Public network access control
  # Note: Azure Data Factory does not have a public_network_access_enabled property
  # Use Azure Firewall rules or Private Link to restrict access
  # The managed VNet provides network isolation for the integration runtime

  # Managed Identity for authentication to Azure services
  # System-assigned identity is used for accessing Key Vault, Storage, etc.
  identity {
    type = "SystemAssigned"
  }

  # Global parameters for Data Factory
  # These can be used across all pipelines and datasets
  dynamic "global_parameter" {
    for_each = var.global_parameters
    content {
      name  = global_parameter.value.name
      type  = global_parameter.value.type
      value = global_parameter.value.value
    }
  }

  tags = var.tags
}

# ===================================
# Azure Integration Runtime (Managed VNet)
# ===================================
# The managed VNet integration runtime provides:
# - Network isolation for data processing
# - Automatic scaling of compute resources
# - Managed private endpoints to Azure services

resource "azurerm_data_factory_integration_runtime_azure" "managed_vnet" {
  count = var.enable_managed_vnet ? 1 : 0

  name            = "${local.data_factory_name_unique}-ir-managed-vnet"
  data_factory_id = azurerm_data_factory.this.id
  location        = var.location

  # Virtual network configuration
  # Enables managed VNet for secure connectivity
  virtual_network_enabled = true

  # Compute configuration
  # core_count: 8 cores (suitable for small to medium workloads)
  # time_to_live_min: Keep runtime alive for 5 minutes to avoid cold starts
  compute_type   = var.integration_runtime_compute_type
  core_count     = var.integration_runtime_core_count
  time_to_live_min = var.integration_runtime_ttl_minutes

  # IMPORTANT: Cleanup setting
  # When enabled, removes all resources when runtime is deleted
  cleanup_enabled = true
}

# ===================================
# Managed Private Endpoint - Storage Account
# ===================================
# Creates a private endpoint from Data Factory managed VNet to Storage Account
# This allows Data Factory to access storage without going through the internet
# Note: Use for_each instead of count to avoid dependency issues with computed values

resource "azurerm_data_factory_managed_private_endpoint" "storage" {
  for_each = var.enable_managed_vnet ? toset(["enabled"]) : toset([])

  name               = "pe-storage"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.storage_account_id
  subresource_name   = "blob" # Connect to blob service

  depends_on = [azurerm_data_factory_integration_runtime_azure.managed_vnet]
}

# ===================================
# Managed Private Endpoint - Key Vault
# ===================================
# Creates a private endpoint from Data Factory managed VNet to Key Vault
# This allows Data Factory to retrieve secrets securely

resource "azurerm_data_factory_managed_private_endpoint" "keyvault" {
  for_each = var.enable_managed_vnet ? toset(["enabled"]) : toset([])

  name               = "pe-keyvault"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.key_vault_id
  subresource_name   = "vault"

  depends_on = [azurerm_data_factory_integration_runtime_azure.managed_vnet]
}

# ===================================
# Linked Service - Azure Key Vault
# ===================================
# Linked service for retrieving secrets from Key Vault
# Uses managed identity authentication

resource "azurerm_data_factory_linked_service_key_vault" "this" {
  for_each = toset(["enabled"]) # Always create Key Vault linked service

  name            = "ls-keyvault"
  data_factory_id = azurerm_data_factory.this.id
  key_vault_id    = var.key_vault_id

  # Use managed VNet integration runtime when available
  integration_runtime_name = var.enable_managed_vnet ? azurerm_data_factory_integration_runtime_azure.managed_vnet[0].name : null

  depends_on = [
    azurerm_data_factory_integration_runtime_azure.managed_vnet,
    azurerm_data_factory_managed_private_endpoint.keyvault
  ]
}

# ===================================
# Linked Service - Azure Blob Storage
# ===================================
# Linked service for accessing Azure Blob Storage
# Uses managed identity authentication

resource "azurerm_data_factory_linked_service_azure_blob_storage" "this" {
  for_each = toset(["enabled"]) # Always create Storage linked service

  name            = "ls-blob-storage"
  data_factory_id = azurerm_data_factory.this.id

  # Use managed identity authentication (more secure than connection strings)
  use_managed_identity = true
  service_endpoint     = "https://${var.storage_account_name}.blob.core.windows.net"

  # Use managed VNet integration runtime when available
  integration_runtime_name = var.enable_managed_vnet ? azurerm_data_factory_integration_runtime_azure.managed_vnet[0].name : null

  depends_on = [
    azurerm_data_factory_integration_runtime_azure.managed_vnet,
    azurerm_data_factory_managed_private_endpoint.storage
  ]
}

# ===================================
# Linked Service - Power Platform (Dataverse)
# ===================================
# Linked service for Power Platform Dataverse
# Uses service principal authentication via Key Vault

resource "azurerm_data_factory_linked_custom_service" "dataverse" {
  for_each = var.enable_dataverse_linked_service ? toset(["enabled"]) : toset([])

  name            = "ls-dataverse"
  data_factory_id = azurerm_data_factory.this.id
  type            = "CommonDataServiceForApps"

  # Type properties for Dataverse connection
  type_properties_json = jsonencode({
    deploymentType               = "Online"
    hostName                     = var.dataverse_environment_url
    organizationName             = var.dataverse_organization_name
    serviceUri                   = var.dataverse_environment_url
    authenticationType           = "ServicePrincipal"
    servicePrincipalId           = var.dataverse_service_principal_id
    servicePrincipalCredentialType = "ServicePrincipalKey"
    servicePrincipalCredential = {
      type  = "AzureKeyVaultSecret"
      store = {
        referenceName = length(azurerm_data_factory_linked_service_key_vault.this) > 0 ? azurerm_data_factory_linked_service_key_vault.this["enabled"].name : "ls-keyvault"
        type          = "LinkedServiceReference"
      }
      secretName = var.dataverse_service_principal_secret_name
    }
    tenant = var.tenant_id
  })

  # Use managed VNet integration runtime when available
  # This ensures outbound traffic goes through NAT Gateway (whitelistable IP)
  integration_runtime {
    name = var.enable_managed_vnet ? azurerm_data_factory_integration_runtime_azure.managed_vnet[0].name : "AutoResolveIntegrationRuntime"
  }

  depends_on = [
    azurerm_data_factory_integration_runtime_azure.managed_vnet,
    azurerm_data_factory_linked_service_key_vault.this
  ]
}

# ===================================
# Linked Service - Azure API Management
# ===================================
# Linked service for calling APIM-hosted APIs
# Uses managed identity or subscription key authentication

resource "azurerm_data_factory_linked_custom_service" "apim" {
  for_each = var.enable_apim_linked_service ? toset(["enabled"]) : toset([])

  name            = "ls-apim"
  data_factory_id = azurerm_data_factory.this.id
  type            = "HttpServer"

  # Type properties for HTTP/APIM connection
  type_properties_json = jsonencode({
    url                   = var.apim_gateway_url
    enableServerCertificateValidation = true
    authenticationType    = var.apim_authentication_type
    # For subscription key auth, reference the key from Key Vault
    # For OAuth, configure additional properties
  })

  # Use managed VNet integration runtime when available
  integration_runtime {
    name = var.enable_managed_vnet ? azurerm_data_factory_integration_runtime_azure.managed_vnet[0].name : "AutoResolveIntegrationRuntime"
  }

  depends_on = [
    azurerm_data_factory_integration_runtime_azure.managed_vnet
  ]
}

# ===================================
# RBAC: Key Vault Access
# ===================================
# Grant Data Factory managed identity access to Key Vault secrets

resource "azurerm_role_assignment" "keyvault_secrets_user" {
  for_each = var.grant_key_vault_permissions ? toset(["enabled"]) : toset([])

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id

  depends_on = [azurerm_data_factory.this]
}

# ===================================
# RBAC: Storage Account Access
# ===================================
# Grant Data Factory managed identity access to storage account

resource "azurerm_role_assignment" "storage_blob_contributor" {
  for_each = var.grant_storage_permissions ? toset(["enabled"]) : toset([])

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id

  depends_on = [azurerm_data_factory.this]
}

# ===================================
# RBAC Propagation Wait
# ===================================
# Wait for RBAC permissions to propagate before using Data Factory

resource "time_sleep" "rbac_propagation" {
  for_each = var.grant_key_vault_permissions || var.grant_storage_permissions ? toset(["enabled"]) : toset([])

  depends_on = [
    azurerm_role_assignment.keyvault_secrets_user,
    azurerm_role_assignment.storage_blob_contributor
  ]

  create_duration = "60s"
}
