variable "key_vault_name" {
  description = "Name of the Key Vault (must be globally unique, 3-24 chars)"
  type        = string
  
  validation {
    condition     = length(var.key_vault_name) >= 3 && length(var.key_vault_name) <= 24
    error_message = "Key Vault name must be between 3 and 24 characters."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "sku_name" {
  description = "SKU name (standard or premium)"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be either 'standard' or 'premium'."
  }
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention in days (7-90)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Retention must be between 7 and 90 days."
  }
}

variable "enable_purge_protection" {
  description = "Enable purge protection"
  type        = bool
  default     = false
}

variable "enable_rbac_authorization" {
  description = "Use RBAC for authorization instead of access policies"
  type        = bool
  default     = true
}

variable "enabled_for_deployment" {
  description = "Enable for Azure VM deployment"
  type        = bool
  default     = false
}

variable "enabled_for_disk_encryption" {
  description = "Enable for disk encryption"
  type        = bool
  default     = false
}

variable "enabled_for_template_deployment" {
  description = "Enable for template deployment"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = true
}

variable "network_acls_default_action" {
  description = "Default action for network ACLs"
  type        = string
  default     = "Allow"
  
  validation {
    condition     = contains(["Allow", "Deny"], var.network_acls_default_action)
    error_message = "Must be either 'Allow' or 'Deny'."
  }
}

variable "allowed_ip_addresses" {
  description = "List of allowed IP addresses"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access Key Vault"
  type        = list(string)
  default     = []
}

variable "admin_object_ids" {
  description = "Object IDs to grant Key Vault Secrets Officer role"
  type        = list(string)
  default     = []
}

variable "reader_object_ids" {
  description = "Object IDs to grant Key Vault Secrets User role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags for the Key Vault"
  type        = map(string)
  default     = {}
}