# ===================================
# Environment Configuration
# ===================================

variable "display_name" {
  description = "Display name of the Power Platform environment"
  type        = string
}

variable "location" {
  description = "Azure region for the environment (e.g., unitedstates, europe, asia)"
  type        = string
  default     = "unitedstates"

  validation {
    condition     = contains(["unitedstates", "europe", "asia", "australia", "india", "japan", "canada", "southamerica", "unitedkingdom", "france", "germany", "unitedarabemirates", "switzerland", "norway", "korea", "southafrica"], var.location)
    error_message = "Location must be a valid Power Platform region."
  }
}

variable "environment_type" {
  description = "Type of environment (Sandbox, Production, Trial, Developer)"
  type        = string
  default     = "Sandbox"

  validation {
    condition     = contains(["Sandbox", "Production", "Trial", "Developer"], var.environment_type)
    error_message = "Environment type must be one of: Sandbox, Production, Trial, Developer."
  }
}

variable "description" {
  description = "Description of the environment"
  type        = string
  default     = ""
}

variable "owner_id" {
  description = "Entra ID user id (guid) of the environment owner when creating developer environment. Only applicable for Developer environment type."
  type        = string
  default     = null
}

variable "release_cycle" {
  description = "Release cycle for the environment. Gives ability to create environments that are updated first."
  type        = string
  default     = null
}

# ===================================
# Dataverse Configuration
# ===================================

variable "language_code" {
  description = "Language code for Dataverse (e.g., 1033 for English)"
  type        = number
  default     = 1033

  validation {
    condition     = var.language_code > 0
    error_message = "Language code must be a positive number."
  }
}

variable "currency_code" {
  description = "Currency code for Dataverse (e.g., USD, EUR, GBP)"
  type        = string
  default     = "USD"
}

variable "security_group_id" {
  description = "Azure AD Security Group ID to restrict access to the environment"
  type        = string
  default     = null
}

# ===================================
# Enterprise Policy Configuration
# ===================================

variable "enable_enterprise_policy" {
  description = "Enable enterprise policy linkage for VNet integration"
  type        = bool
  default     = false
}

variable "enterprise_policy_id" {
  description = "Enterprise Policy ID for subnet delegation and VNet integration (optional)"
  type        = string
  default     = null
}

# ===================================
# Application User Configuration
# ===================================

variable "create_application_user" {
  description = "Whether to create an application user from app registration (legacy, use application_users for multiple)"
  type        = bool
  default     = true
}

variable "application_client_id" {
  description = "Client ID of the Azure AD app registration to add as application user (legacy, use application_users for multiple)"
  type        = string
  default     = ""
}

variable "security_roles" {
  description = "List of security roles to assign to the application user"
  type        = list(string)
  default     = ["System Administrator"]

  validation {
    condition     = alltrue([for role in var.security_roles : contains(["System Administrator", "Service Reader", "Service Writer", "System Customizer", "Environment Maker"], role)])
    error_message = "Security roles must be valid Dataverse roles."
  }
}

variable "additional_application_users" {
  description = "Additional application users to create in the environment (list of client IDs)"
  type        = list(string)
  default     = []
}

# ===================================
# Managed Environment Configuration
# ===================================

variable "enable_managed_environment" {
  description = "Enable Managed Environment features (required for IP firewall)"
  type        = bool
  default     = false
}

variable "managed_env_is_group_sharing_disabled" {
  description = "Disable group sharing in Managed Environment"
  type        = bool
  default     = false
}

variable "managed_env_is_usage_insights_disabled" {
  description = "Disable usage insights in Managed Environment"
  type        = bool
  default     = false
}

variable "managed_env_limit_sharing_mode" {
  description = "Limit sharing mode (e.g., ExcludeSharingToSecurityGroups)"
  type        = string
  default     = "ExcludeSharingToSecurityGroups"
}

variable "managed_env_max_limit_user_sharing" {
  description = "Maximum number of users who can share canvas apps (-1 when group sharing enabled)"
  type        = number
  default     = 10
}

variable "managed_env_solution_checker_mode" {
  description = "Solution checker enforcement mode (None, Warn, Block)"
  type        = string
  default     = "None"

  validation {
    condition     = contains(["None", "Warn", "Block"], var.managed_env_solution_checker_mode)
    error_message = "Solution checker mode must be one of: None, Warn, Block."
  }
}

variable "managed_env_suppress_validation_emails" {
  description = "Suppress validation emails (only send for blocked solutions)"
  type        = bool
  default     = true
}

variable "managed_env_maker_onboarding_markdown" {
  description = "Markdown content for first-time Power Apps makers"
  type        = string
  default     = "Welcome to Power Apps! Please follow best practices."
}

variable "managed_env_maker_onboarding_url" {
  description = "URL for maker onboarding Learn more links"
  type        = string
  default     = "https://learn.microsoft.com/power-apps/"
}

# ===================================
# IP Firewall Configuration
# ===================================

variable "enable_ip_firewall" {
  description = "Enable IP firewall configuration using powerplatform_environment_settings (requires enable_managed_environment = true)"
  type        = bool
  default     = false
}

variable "enable_terraform_runner_ip" {
  description = "Automatically include the IP of the machine running Terraform in allowed IPs"
  type        = bool
  default     = true
}

variable "terraform_runner_ip" {
  description = "Manual IP address of the Terraform runner (optional, auto-detected if not provided when enable_terraform_runner_ip is true)"
  type        = string
  default     = null

  validation {
    condition     = var.terraform_runner_ip == null || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.terraform_runner_ip))
    error_message = "Terraform runner IP must be a valid IPv4 address (e.g., '1.2.3.4')."
  }
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges in CIDR format (e.g., ['1.2.3.4/32', '10.0.0.0/24'])"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.allowed_ip_ranges :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", ip))
    ])
    error_message = "IP ranges must be in valid CIDR format (e.g., '1.2.3.4/32')."
  }
}

variable "ip_firewall_audit_mode" {
  description = "Enable IP firewall in audit mode (logs but doesn't block)"
  type        = bool
  default     = false
}

variable "ip_firewall_allow_application_users" {
  description = "Allow application users to bypass IP firewall"
  type        = bool
  default     = true
}

variable "ip_firewall_allow_microsoft_services" {
  description = "Allow Microsoft trusted services to bypass IP firewall"
  type        = bool
  default     = true
}

variable "ip_firewall_allowed_service_tags" {
  description = "List of Azure service tags allowed to bypass IP firewall (e.g., ['ApiManagement', 'AppService'])"
  type        = list(string)
  default     = null
}

variable "ip_firewall_reverse_proxy_ips" {
  description = "List of reverse proxy IP addresses that send client IPs in forwarded header"
  type        = list(string)
  default     = null
}

variable "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway to allow in IP firewall for VNet-based Azure services"
  type        = string
  default     = null
}

# ===================================
# Solution Import Configuration
# ===================================

variable "solutions" {
  description = "List of Power Platform solutions to import into the environment"
  type = list(object({
    solution_name    = string # Unique name for the solution (used in Terraform resource naming)
    solution_file    = string # Path to the solution ZIP file
    settings_file    = string # Optional: Path to settings file for environment variables and connections (can be empty string)
    activate_plugins = bool   # Whether to activate plugins after import
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.solutions : s.solution_name != "" && s.solution_file != ""
    ])
    error_message = "Each solution must have a non-empty solution_name and solution_file."
  }
}

variable "solution_folder" {
  description = "Path to unpacked solution folder for custom solution packing (leave empty if not using custom solution)"
  type        = string
  default     = ""
}

variable "managed_identity_id" {
  description = "Application (client) ID of the app registration used for Dataverse plugin authentication. This value replaces {REPLACE_MANAGEDIDENTITYID} tokens in solution XML files."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure Tenant ID where the app registration is defined. This value replaces {REPLACE_TENANTID} tokens in solution XML files."
  type        = string
  default     = ""
}

variable "solution_pack_zip_path" {
  description = "Output path for the packed solution ZIP file"
  type        = string
  default     = ""
}
