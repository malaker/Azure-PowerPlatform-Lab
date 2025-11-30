# ===================================
# Core Configuration Variables
# ===================================

variable "subscription_id" {
  description = "Azure Subscription ID (required for AzureRM provider v4+)"
  type        = string
  default     = null # Will use Azure CLI default subscription if not specified
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "IntegrationGuide"

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 20
    error_message = "Project name must be between 1 and 20 characters."
  }
}

variable "default_power_platform_owner_id" {
  description = "Default Entra ID user GUID for Power Platform Developer environment owners"
  type        = string
  default     = null
}

# ===================================
# Organizational Tagging Variables
# ===================================

variable "cost_center" {
  description = "Cost center for resource billing and tracking"
  type        = string
  default     = "Engineering"
}

variable "owner" {
  description = "Owner or team responsible for the resources"
  type        = string
  default     = "Platform Team"
}

variable "data_classification" {
  description = "Data classification level (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "Data classification must be one of: public, internal, confidential, restricted."
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ===================================
# Resource Group Configuration
# ===================================

variable "resource_groups" {
  description = "List of resource groups to create (will be prefixed with rg-{environment}-)"
  type = list(object({
    name     = string
    purpose  = optional(string)
    location = optional(string)
    tags     = optional(map(string), {})
  }))
  default = []
}

# ===================================
# App Registration Configuration
# ===================================

variable "app_registrations" {
  description = "List of app registrations to create"
  type = list(object({
    name                     = string
    description              = string
    sign_in_audience         = optional(string)
    redirect_uris            = optional(list(string), [])
    required_resource_access = optional(list(object({
      resource_app_id = string
      resource_access = list(object({
        id   = string
        type = string
      }))
    })), [])
    expose_api            = optional(bool, false)
    api_scope_name        = optional(string, "access_as_application")
    api_scope_description = optional(string, "Access the API as an application")
    expose_app_roles      = optional(bool, false)
    app_roles = optional(list(object({
      display_name = string
      description  = string
      value        = string
      enabled      = bool
    })), [])
  }))
  default = []
}

# ===================================
# Key Vault Configuration
# ===================================

variable "key_vault_sku" {
  description = "SKU for Key Vault (standard or premium) - can be overridden from environment config"
  type        = string
  default     = null

  validation {
    condition     = var.key_vault_sku == null || contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be either 'standard' or 'premium'."
  }
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention in days - can be overridden from environment config"
  type        = number
  default     = null

  validation {
    condition     = var.soft_delete_retention_days == null || (var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90)
    error_message = "Soft delete retention must be between 7 and 90 days."
  }
}

variable "enable_purge_protection" {
  description = "Enable purge protection for Key Vault - can be overridden from environment config"
  type        = bool
  default     = null
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses allowed to access Key Vault"
  type        = list(string)
  default     = []
}

# ===================================
# Network Configuration
# ===================================

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for outbound internet traffic with static public IP (recommended for production)"
  type        = bool
  default     = true
}

# ===================================
# Power Platform Configuration
# ===================================

variable "power_platform_environments" {
  description = "List of Power Platform environments to create"
  type = list(object({
    name                            = string
    description                     = string
    location                        = optional(string, "europe")
    environment_type                = optional(string, "Developer")
    owner_id                        = optional(string)         # Entra ID user id (guid) - only for Developer environments
    release_cycle                   = optional(string)         # Release cycle (e.g., "Frequent", "Moderate")
    language_code                   = optional(number, 1033)
    currency_code                   = optional(string, "EUR")
    security_group_id               = optional(string)
    create_app_user                 = optional(bool, true)
    app_registration                = optional(string)         # Name of app registration from app_registrations list
    additional_app_registrations    = optional(list(string), []) # Additional app registrations to add as application users
    security_roles                  = optional(list(string), ["System Administrator"])
    enable_managed_environment      = optional(bool, false)    # Enable managed environment features
  }))
  default = []
}

# ===================================
# Power Platform Subnet Delegation
# ===================================

variable "enable_powerplatform_subnet_delegation" {
  description = "Enable Power Platform subnet delegation on the existing subnet-powerplatform with enterprise policies for VNet integration"
  type        = bool
  default     = false
}

# ===================================
# Federated Credentials for Power Platform
# ===================================

variable "powerplatform_federated_credential_mode" {
  description = "Mode for federated credential subject pattern: 'production' uses /i/{issuer}/s/{subject} pattern (for well-known CA signed certificates), 'development' uses /hash/{sha256} pattern (for self-signed certificates)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["production", "development"], var.powerplatform_federated_credential_mode)
    error_message = "Federated credential mode must be either 'production' or 'development'."
  }
}

variable "powerplatform_federated_credential_issuer" {
  description = "Issuer value for Power Platform federated credential (required for production mode)"
  type        = string
  default     = ""
}

variable "powerplatform_federated_credential_certificate_subject" {
  description = "Certificate subject for Power Platform federated credential (required for production mode)"
  type        = string
  default     = ""
}

variable "powerplatform_federated_credential_certificate_hash" {
  description = "SHA256 hash of the certificate for Power Platform federated credential (required for development mode)"
  type        = string
  default     = ""
}

# ===================================
# API Management Configuration
# ===================================

variable "enable_api_management" {
  description = "Enable Azure API Management deployment"
  type        = bool
  default     = false
}

variable "enable_data_factory" {
  description = "Enable Azure Data Factory deployment"
  type        = bool
  default     = false
}

variable "enable_logic_apps" {
  description = "Enable Logic App Standard deployment"
  type        = bool
  default     = true
}

variable "apim_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "Integration Guide"
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
  default     = ""
}

variable "apim_sku_name" {
  description = "SKU name for API Management. Developer_1 is the cheapest option supporting VNet integration."
  type        = string
  default     = "Developer_1"
}

variable "apim_virtual_network_type" {
  description = "Virtual network type for API Management: None, External, or Internal. Internal means APIM is only accessible from within VNet."
  type        = string
  default     = "Internal"
}

variable "apim_enable_public_endpoint" {
  description = "Enable public endpoint for API Management. When false (default), APIM is only accessible from within VNet."
  type        = bool
  default     = false
}

variable "apim_enable_bff_api" {
  description = "Enable BFF (Backend for Frontend) API on APIM"
  type        = bool
  default     = true
}

variable "apim_bff_openapi_spec_path" {
  description = "Path to the OpenAPI specification file for the BFF API"
  type        = string
  default     = ""
}

variable "apim_oauth_audience_app_registration" {
  description = "Name of the app registration to use as OAuth 2.0 audience for APIM (e.g., 'az-function-backend')"
  type        = string
  default     = "az-function-backend"
}

# ===================================
# Function App Configuration
# ===================================

variable "additional_function_app_settings" {
  description = "Additional application settings for the Function App (merged with default Dataverse settings)"
  type        = map(string)
  default     = {}
}

# ===================================
# Logic App Configuration
# ===================================

variable "additional_logic_app_settings" {
  description = "Additional application settings for Logic App Standard (merged with default settings)"
  type        = map(string)
  default     = {}
}