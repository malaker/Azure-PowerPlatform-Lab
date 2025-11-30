output "environment_id" {
  description = "ID of the Power Platform environment"
  value       = powerplatform_environment.this.id
}

output "environment_url" {
  description = "URL of the Power Platform environment"
  value       = powerplatform_environment.this.dataverse.url
}

output "environment_name" {
  description = "Display name of the environment"
  value       = powerplatform_environment.this.display_name
}

output "environment_domain" {
  description = "Domain name of the environment (derived from URL)"
  value       = try(regex("https://([^.]+)", powerplatform_environment.this.dataverse.url)[0], "")
}

output "dataverse_organization_id" {
  description = "Organization ID of the Dataverse instance"
  value       = powerplatform_environment.this.dataverse.organization_id
}

output "application_user_id" {
  description = "ID of the application user (if created)"
  value       = var.create_application_user && length(powerplatform_environment_application_admin.app_user) > 0 ? powerplatform_environment_application_admin.app_user[0].id : null
}

output "assigned_roles" {
  description = "List of roles assigned to the application user (automatically assigned System Administrator)"
  value       = var.create_application_user ? ["System Administrator"] : []
}

# ===================================
# Managed Environment Outputs
# ===================================

output "is_managed_environment" {
  description = "Whether this environment is configured as a Managed Environment"
  value       = var.enable_managed_environment
}

# output "managed_environment_id" {
#   description = "ID of the Managed Environment settings (if enabled)"
#   value       = var.enable_managed_environment && length(powerplatform_managed_environment.this) > 0 ? powerplatform_managed_environment.this[0].id : null
# }

# ===================================
# IP Firewall Outputs
# ===================================

output "terraform_runner_ip" {
  description = "Public IP address of the machine running Terraform"
  value       = local.current_ip
}

output "allowed_ip_ranges_for_firewall" {
  description = "List of allowed IP ranges to configure in Power Platform IP Firewall (comma-separated format ready for API)"
  value       = local.allowed_ips_string
}

output "ip_firewall_enabled" {
  description = "Whether IP firewall is enabled for this environment"
  value       = var.enable_ip_firewall
}

output "ip_firewall_settings_id" {
  description = "ID of the environment settings resource (if IP firewall is enabled)"
  value       = var.enable_ip_firewall && length(powerplatform_environment_settings.this) > 0 ? powerplatform_environment_settings.this[0].id : null
}

output "ip_firewall_audit_mode" {
  description = "Whether IP firewall is in audit mode (logs but doesn't block)"
  value       = var.enable_ip_firewall ? var.ip_firewall_audit_mode : null
}

# ===================================
# Solution Import Outputs
# ===================================

# COMMENTED OUT: Outputs disabled because solution import is disabled
# Uncomment these when re-enabling powerplatform_solution resource
# output "imported_solutions" {
#   description = "Map of imported solution names to their resource IDs"
#   value = {
#     for k, v in powerplatform_solution.solutions : k => v.id
#   }
# }
#
# output "imported_solution_details" {
#   description = "Detailed information about imported solutions"
#   value = {
#     for k, v in powerplatform_solution.solutions : k => {
#       id               = v.id
#       solution_file    = v.solution_file
#       environment_id   = v.environment_id
#     }
#   }
# }

output "imported_solutions" {
  description = "Map of imported solution names to their resource IDs (currently disabled - import solutions manually)"
  value       = {}
}

output "imported_solution_details" {
  description = "Detailed information about imported solutions (currently disabled - import solutions manually)"
  value       = {}
}
