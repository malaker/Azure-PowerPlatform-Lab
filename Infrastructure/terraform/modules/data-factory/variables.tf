# ===================================
# Required Variables
# ===================================

variable "data_factory_name" {
  description = "Name of the Data Factory (globally unique, 3-63 chars)"
  type        = string
}

variable "random_suffix" {
  description = "Random suffix for unique resource naming (shared across all resources)"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

# ===================================
# Network Configuration
# ===================================

variable "enable_managed_vnet" {
  description = "Enable managed virtual network for Data Factory integration runtime"
  type        = bool
  default     = true
}

# Note: public_network_access_enabled is not supported by azurerm_data_factory resource
# Use Azure Firewall rules or Private Link for access control instead

# ===================================
# Integration Runtime Configuration
# ===================================

variable "integration_runtime_compute_type" {
  description = "Compute type for Azure Integration Runtime (General, MemoryOptimized, ComputeOptimized)"
  type        = string
  default     = "General"
}

variable "integration_runtime_core_count" {
  description = "Number of cores for Azure Integration Runtime (8, 16, 32, 64, 128, 256)"
  type        = number
  default     = 8
}

variable "integration_runtime_ttl_minutes" {
  description = "Time to live in minutes for Azure Integration Runtime (0 = no TTL)"
  type        = number
  default     = 5
}

# ===================================
# Storage Account Configuration
# ===================================

variable "storage_account_id" {
  description = "Storage account resource ID for managed private endpoint"
  type        = string
  default     = null
}

variable "storage_account_name" {
  description = "Storage account name for linked service"
  type        = string
  default     = null
}

# ===================================
# Key Vault Configuration
# ===================================

variable "key_vault_id" {
  description = "Key Vault resource ID for managed private endpoint and linked service"
  type        = string
  default     = null
}

# ===================================
# Power Platform (Dataverse) Configuration
# ===================================

variable "enable_dataverse_linked_service" {
  description = "Create Dataverse linked service for Power Platform integration"
  type        = bool
  default     = false
}

variable "dataverse_environment_url" {
  description = "Dataverse environment URL (e.g., https://org.crm4.dynamics.com)"
  type        = string
  default     = null
}

variable "dataverse_organization_name" {
  description = "Dataverse organization name"
  type        = string
  default     = null
}

variable "dataverse_service_principal_id" {
  description = "Service principal (client) ID for Dataverse authentication"
  type        = string
  default     = null
}

variable "dataverse_service_principal_secret_name" {
  description = "Key Vault secret name containing service principal secret"
  type        = string
  default     = null
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = null
}

# ===================================
# API Management Configuration
# ===================================

variable "enable_apim_linked_service" {
  description = "Create APIM linked service for API integration"
  type        = bool
  default     = false
}

variable "apim_gateway_url" {
  description = "API Management gateway URL (e.g., https://apim.azure-api.net)"
  type        = string
  default     = null
}

variable "apim_authentication_type" {
  description = "APIM authentication type (Anonymous, Basic, ClientCertificate, ServicePrincipal)"
  type        = string
  default     = "Anonymous"
}

# ===================================
# Global Parameters
# ===================================

variable "global_parameters" {
  description = "Global parameters for Data Factory pipelines"
  type = list(object({
    name  = string
    type  = string
    value = string
  }))
  default = []
}

# ===================================
# RBAC Configuration
# ===================================

variable "grant_key_vault_permissions" {
  description = "Grant Key Vault RBAC permissions to Data Factory managed identity"
  type        = bool
  default     = true
}

variable "grant_storage_permissions" {
  description = "Grant Storage RBAC permissions to Data Factory managed identity"
  type        = bool
  default     = true
}

# ===================================
# Tags
# ===================================

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
