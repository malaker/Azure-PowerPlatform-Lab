# ===================================
# Naming and Uniqueness
# ===================================

output "random_suffix" {
  description = "Random suffix used for globally unique resource names"
  value       = local.random_suffix
}

# ===================================
# Resource Groups
# ===================================

output "resource_group_ids" {
  description = "IDs of created resource groups"
  value       = { for k, v in module.resource_groups : k => v.id }
}

output "resource_group_names" {
  description = "Names of created resource groups"
  value       = { for k, v in module.resource_groups : k => v.name }
}

output "keyvaults_resource_group_name" {
  description = "Name of the Key Vaults resource group"
  value       = module.resource_groups["keyvaults"].name
}

output "logicapps_resource_group_name" {
  description = "Name of the Logic Apps resource group"
  value       = module.resource_groups["logicapps"].name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.key_vault.key_vault_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.key_vault_uri
}

output "app_registration_details" {
  description = "Details of created app registrations"
  value = {
    for k, v in module.app_registrations : k => {
      application_id  = v.application_id
      object_id       = v.object_id
      client_id       = v.client_id
      secret_key_name = v.secret_key_name
      api_scope_id    = v.api_scope_id
      identifier_uri  = v.identifier_uri
    }
  }
}

output "app_client_ids" {
  description = "Client IDs of app registrations"
  value       = { for k, v in module.app_registrations : k => v.client_id }
}

# Sensitive outputs
output "app_secrets_location" {
  description = "Location of app secrets in Key Vault"
  value       = "Secrets stored in Key Vault: ${module.key_vault.key_vault_name}"
}

output "app_permissions_granted" {
  description = "API permissions automatically granted between app registrations"
  value = {
    "power-platform-svc to az-function-backend" = {
      delegated_permission = "access_as_user (OAuth2 scope)"
      application_permission = "API.Access.All (App role)"
      status = "Admin consent automatically granted by Terraform"
    }
  }
}

# ===================================
# Power Platform Outputs
# ===================================

output "power_platform_environments" {
  description = "Power Platform environment details"
  value = {
    for k, v in module.powerplatform : k => {
      environment_id  = v.environment_id
      environment_url = v.environment_url
      display_name    = v.environment_name
      domain          = v.environment_domain
    }
  }
}

output "power_platform_environment_urls" {
  description = "URLs of Power Platform environments"
  value       = { for k, v in module.powerplatform : k => v.environment_url }
}

output "power_platform_application_users" {
  description = "Application user IDs in Power Platform environments"
  value       = { for k, v in module.powerplatform : k => v.application_user_id }
}

output "power_platform_imported_solutions" {
  description = "Imported solutions in Power Platform environments"
  value       = { for k, v in module.powerplatform : k => v.imported_solutions }
}

output "power_platform_solution_details" {
  description = "Detailed information about imported solutions"
  value       = { for k, v in module.powerplatform : k => v.imported_solution_details }
}

# ===================================
# Function App Outputs
# ===================================

output "function_app_name" {
  description = "Name of the Function App"
  value       = module.function_app.function_app_name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = module.function_app.function_app_default_hostname
}

output "function_app_principal_id" {
  description = "Principal ID of the Function App managed identity"
  value       = module.function_app.function_app_principal_id
}

output "function_app_storage_rbac_roles" {
  description = "Storage RBAC roles granted to Function App managed identity"
  value = {
    storage_account = module.storage_account_functions.storage_account_name
    roles = [
      "Storage Blob Data Contributor",
      "Storage Queue Data Contributor",
      "Storage Table Data Contributor"
    ]
    status = "Automatically granted by Terraform for managed identity authentication"
  }
}

output "function_app_dataverse_configuration" {
  description = "Dataverse configuration in Function App application settings"
  value = {
    dataverse_url = length(module.powerplatform) > 0 ? module.powerplatform[keys(module.powerplatform)[0]].environment_url : "No Power Platform environment configured"
    app_registration = "az-function-backend"
    client_id_source = "Key Vault secret reference"
    client_secret_source = "Key Vault secret reference"
    tenant_id = data.azurerm_client_config.current.tenant_id
    keyvault_access = "Function App has 'Key Vault Secrets User' role"
    configuration_keys = [
      "Dataverse__Url",
      "Dataverse__AppRegistration__ClientId (Key Vault reference)",
      "Dataverse__AppRegistration__ClientSecret (Key Vault reference)",
      "Dataverse__AppRegistration__TenantId"
    ]
  }
}

output "storage_account_network_configuration" {
  description = "Storage account network access configuration"
  value = {
    storage_account        = module.storage_account_functions.storage_account_name
    default_action         = "Deny"
    network_bypass         = ["AzureServices", "Logging", "Metrics"]
    allowed_subnets = [
      "subnet-functions (Function App runtime)",
      "subnet-apim (API Management)",
      "subnet-powerplatform West Europe",
      var.enable_powerplatform_subnet_delegation ? "subnet-powerplatform North Europe" : null
    ]
    status = "Network rules configured to allow access only from specified VNet subnets"
  }
}

# ===================================
# API Management Outputs
# ===================================

output "api_management_id" {
  description = "ID of the API Management instance"
  value       = var.enable_api_management ? module.api_management[0].id : null
}

output "api_management_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = var.enable_api_management ? module.api_management[0].gateway_url : null
}

output "api_management_developer_portal_url" {
  description = "Developer portal URL of the API Management instance"
  value       = var.enable_api_management ? module.api_management[0].developer_portal_url : null
}

output "api_management_private_ip_addresses" {
  description = "Private IP addresses of the API Management instance"
  value       = var.enable_api_management ? module.api_management[0].private_ip_addresses : null
}

output "api_management_bff_api_url" {
  description = "URL of the BFF API on API Management"
  value       = var.enable_api_management ? module.api_management[0].bff_api_url : null
}

output "api_management_private_dns_zone" {
  description = "Private DNS zone for API Management (specific hostname zone)"
  value       = var.enable_api_management && var.apim_virtual_network_type == "Internal" ? azurerm_private_dns_zone.apim[0].name : null
}

output "api_management_private_dns_fqdn" {
  description = "Fully qualified domain name for API Management in Private DNS (same as zone name)"
  value       = var.enable_api_management && var.apim_virtual_network_type == "Internal" ? azurerm_private_dns_zone.apim[0].name : null
}