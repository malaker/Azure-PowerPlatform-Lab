variable "name" {
  description = "Name of the API Management instance"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the resource"
  type        = string
}

variable "publisher_name" {
  description = "Publisher name for the API Management instance"
  type        = string
}

variable "publisher_email" {
  description = "Publisher email for the API Management instance"
  type        = string
}

variable "sku_name" {
  description = "SKU name for API Management. Developer is the cheapest option supporting VNet integration."
  type        = string
  default     = "Developer_1"

  validation {
    condition     = can(regex("^(Developer|Basic|Standard|Premium)_[0-9]+$", var.sku_name))
    error_message = "SKU name must be in format {Tier}_{Capacity}, e.g., Developer_1, Basic_1, Standard_1, Premium_1."
  }
}

variable "virtual_network_type" {
  description = "Virtual network type: None, External, or Internal"
  type        = string
  default     = "External"

  validation {
    condition     = contains(["None", "External", "Internal"], var.virtual_network_type)
    error_message = "Virtual network type must be None, External, or Internal."
  }
}

variable "subnet_id" {
  description = "Subnet ID for VNet integration (required when virtual_network_type is External or Internal)"
  type        = string
  default     = ""
}

variable "public_ip_address_id" {
  description = "Public IP address ID for external VNet mode (required for Developer/Premium SKUs with External VNet)"
  type        = string
  default     = ""
}

variable "public_network_access_enabled" {
  description = "Enable public network access to the API Management gateway and management endpoints"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ===================================
# BFF API Configuration
# ===================================

variable "enable_bff_api" {
  description = "Enable BFF (Backend for Frontend) API"
  type        = bool
  default     = false
}

variable "bff_openapi_spec_path" {
  description = "Path to the OpenAPI specification file for the BFF API"
  type        = string
  default     = ""
}

variable "bff_backend_url" {
  description = "Backend URL for the BFF API (Azure Function App URL)"
  type        = string
  default     = ""
}

variable "oauth_tenant_id" {
  description = "Azure AD tenant ID for OAuth 2.0 token validation"
  type        = string
  default     = ""
}

variable "oauth_audience" {
  description = "Expected audience (client ID) for OAuth 2.0 token validation"
  type        = string
  default     = ""
}
