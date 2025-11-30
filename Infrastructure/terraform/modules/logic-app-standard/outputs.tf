# ===================================
# Infrastructure Outputs
# ===================================

output "app_service_plan_id" {
  description = "App Service Plan ID"
  value       = var.create_app_service_plan ? azurerm_service_plan.this[0].id : var.app_service_plan_id
}

output "app_service_plan_name" {
  description = "App Service Plan name"
  value       = var.create_app_service_plan ? azurerm_service_plan.this[0].name : null
}

# ===================================
# Logic App Outputs
# ===================================

output "logic_app_id" {
  description = "Logic App Standard resource ID"
  value       = azurerm_logic_app_standard.this.id
}

output "logic_app_name" {
  description = "Logic App Standard name"
  value       = azurerm_logic_app_standard.this.name
}

output "logic_app_default_hostname" {
  description = "Logic App default hostname"
  value       = azurerm_logic_app_standard.this.default_hostname
}

output "logic_app_principal_id" {
  description = "Logic App Managed Identity principal ID"
  value       = azurerm_logic_app_standard.this.identity[0].principal_id
}

output "logic_app_tenant_id" {
  description = "Logic App Managed Identity tenant ID"
  value       = azurerm_logic_app_standard.this.identity[0].tenant_id
}

# ===================================
# Storage Account Outputs
# ===================================

output "storage_account_name" {
  description = "Storage account name"
  value       = var.storage_account_name
}

output "storage_account_id" {
  description = "Storage account resource ID"
  value       = var.storage_account_id
}

# ===================================
# Deployment Information
# ===================================

output "resource_group_name" {
  description = "Resource group name"
  value       = var.resource_group_name
}

output "location" {
  description = "Azure region"
  value       = var.location
}

output "subnet_id" {
  description = "Subnet ID for VNet integration"
  value       = var.virtual_network_subnet_id
}
