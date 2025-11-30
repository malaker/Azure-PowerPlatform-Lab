# ===================================
# Common Variables
# ===================================

variable "resource_group_name" {
  description = "Resource group name for API connections"
  type        = string
}

variable "location" {
  description = "Azure region for API connections"
  type        = string
}

variable "tags" {
  description = "Tags to apply to API connections"
  type        = map(string)
  default     = {}
}

# ===================================
# Key Vault Variables
# ===================================

variable "key_vault_id" {
  description = "Key Vault resource ID for RBAC assignments"
  type        = string
}

variable "key_vault_uri" {
  description = "Key Vault URI (e.g., https://kv-name.vault.azure.net/)"
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault name"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
}

# ===================================
# Logic App Variables
# ===================================

variable "logic_app_principal_id" {
  description = "Logic App Managed Identity principal ID"
  type        = string
  default     = null
}

variable "grant_keyvault_access" {
  description = "Grant Logic App Managed Identity access to Key Vault"
  type        = bool
  default     = true
}

# ===================================
# Dataverse Connection Variables
# ===================================

variable "create_dataverse_connection" {
  description = "Create Common Data Service (Dataverse) connection"
  type        = bool
  default     = false
}

variable "dataverse_connection_name" {
  description = "Name for the Dataverse API connection"
  type        = string
  default     = "commondataservice"
}

variable "dataverse_connection_display_name" {
  description = "Display name for the Dataverse API connection"
  type        = string
  default     = "Common Data Service"
}

variable "dataverse_client_id" {
  description = "Client ID for Dataverse service principal"
  type        = string
  default     = ""
}

variable "dataverse_client_secret_name" {
  description = "Name of the Key Vault secret containing Dataverse client secret"
  type        = string
  default     = ""
}

variable "dataverse_environment_url" {
  description = "Dataverse environment URL (e.g., https://org.crm4.dynamics.com)"
  type        = string
  default     = ""
}

# ===================================
# Key Vault Connection Variables
# ===================================

variable "create_keyvault_connection" {
  description = "Create Azure Key Vault connection"
  type        = bool
  default     = false
}

variable "keyvault_connection_name" {
  description = "Name for the Key Vault API connection"
  type        = string
  default     = "keyvault"
}

variable "keyvault_connection_display_name" {
  description = "Display name for the Key Vault API connection"
  type        = string
  default     = "Azure Key Vault"
}

# ===================================
# Custom API Connection Variables
# ===================================

variable "create_custom_api_connection" {
  description = "Create custom API connection"
  type        = bool
  default     = false
}

variable "custom_api_connection_name" {
  description = "Name for the custom API connection"
  type        = string
  default     = "custom-api"
}

variable "custom_api_connection_display_name" {
  description = "Display name for the custom API connection"
  type        = string
  default     = "Custom API"
}

variable "custom_api_key_secret_name" {
  description = "Name of the Key Vault secret containing custom API key"
  type        = string
  default     = ""
}
