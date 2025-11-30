variable "display_name" {
  description = "Display name for the application"
  type        = string
}

variable "description" {
  description = "Description of the application"
  type        = string
  default     = ""
}

variable "sign_in_audience" {
  description = "Who can sign in to this application"
  type        = string
  default     = "AzureADMyOrg"
  
  validation {
    condition = contains([
      "AzureADMyOrg",
      "AzureADMultipleOrgs",
      "AzureADandPersonalMicrosoftAccount",
      "PersonalMicrosoftAccount"
    ], var.sign_in_audience)
    error_message = "Invalid sign_in_audience value."
  }
}

variable "redirect_uris" {
  description = "List of redirect URIs"
  type        = list(string)
  default     = []
}

variable "required_resource_access" {
  description = "API permissions required by the application"
  type = list(object({
    resource_app_id = string
    resource_access = list(object({
      id   = string
      type = string
    }))
  }))
  default = []
}

variable "app_role_assignment_required" {
  description = "Whether app role assignment is required"
  type        = bool
  default     = false
}

variable "secret_expiration" {
  description = "Client secret expiration (e.g., '8760h' for 1 year)"
  type        = string
  default     = "8760h" # 1 year
}

variable "store_secret_in_keyvault" {
  description = "Store client secret in Key Vault"
  type        = bool
  default     = true
}

variable "key_vault_id" {
  description = "Key Vault ID for storing secrets"
  type        = string
  default     = ""
}

variable "federated_credentials" {
  description = "List of federated identity credentials for workload identity federation"
  type = list(object({
    display_name = string
    description  = string
    issuer       = string
    subject      = string
    audiences    = list(string)
  }))
  default = []
}

variable "expose_api" {
  description = "Expose an API with oauth2 permission scope (for resource/audience apps)"
  type        = bool
  default     = false
}

variable "api_scope_name" {
  description = "Name of the API scope to expose (e.g., 'access_as_application')"
  type        = string
  default     = "access_as_application"
}

variable "api_scope_description" {
  description = "Description of the API scope"
  type        = string
  default     = "Access the API as an application"
}

variable "expose_app_roles" {
  description = "Expose app roles for application permissions (for client credentials flow)"
  type        = bool
  default     = false
}

variable "app_roles" {
  description = "List of app roles to expose for application permissions"
  type = list(object({
    display_name = string
    description  = string
    value        = string
    enabled      = bool
  }))
  default = []
}