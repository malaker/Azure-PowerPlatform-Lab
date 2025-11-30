# ===================================
# Required Variables
# ===================================

variable "logic_app_name" {
  description = "Name of the Logic App Standard (to be deployed separately)"
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

variable "storage_account_name" {
  description = "Storage account name for Logic App runtime"
  type        = string
}

variable "storage_account_access_key" {
  description = "Storage account access key"
  type        = string
  sensitive   = true
}

variable "storage_account_id" {
  description = "Storage account resource ID (for RBAC)"
  type        = string
}

# ===================================
# Identity Variables
# ===================================

variable "use_user_assigned_identity" {
  description = "Use user-assigned managed identity instead of system-assigned (recommended for network-restricted storage)"
  type        = bool
  default     = false
}

# ===================================
# App Service Plan Variables
# ===================================

variable "create_app_service_plan" {
  description = "Create a new App Service Plan (false to use existing)"
  type        = bool
  default     = false
}

variable "app_service_plan_id" {
  description = "Existing App Service Plan ID (required if create_app_service_plan = false)"
  type        = string
  default     = null
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan (required if create_app_service_plan = true)"
  type        = string
  default     = null
}

variable "sku_name" {
  description = "SKU name for App Service Plan (WS1, WS2, WS3)"
  type        = string
  default     = "WS1"
}

# ===================================
# Application Settings
# ===================================

variable "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  type        = string
  default     = ""
  sensitive   = true
}

# ===================================
# Configuration for Deployment
# ===================================

variable "app_settings" {
  description = "Application settings to be used during Logic App deployment (output only, not applied by Terraform)"
  type        = map(string)
  default     = {}
}

variable "virtual_network_subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
}

variable "vnet_route_all_enabled" {
  description = "Route all outbound traffic through VNet"
  type        = bool
  default     = true
}

variable "enable_vnet_content_access" {
  description = "Enable VNet content access (WEBSITE_CONTENTOVERVNET)"
  type        = bool
  default     = true
}

variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "always_on" {
  description = "Enable Always On"
  type        = bool
  default     = true
}

variable "ip_restrictions" {
  description = "List of inbound IP restrictions - supports both subnet-based and service tag rules"
  type = list(object({
    name                      = string
    virtual_network_subnet_id = optional(string)
    service_tag               = optional(string)
    priority                  = number
    action                    = string
  }))
  default = []
}

# ===================================
# RBAC Variables
# ===================================

variable "grant_key_vault_permissions" {
  description = "Grant Key Vault RBAC permissions to Logic App Managed Identity"
  type        = bool
  default     = true
}

variable "key_vault_id" {
  description = "Key Vault resource ID (for RBAC assignment)"
  type        = string
  default     = ""
}

variable "grant_storage_permissions" {
  description = "Grant storage RBAC permissions to Logic App Managed Identity"
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
