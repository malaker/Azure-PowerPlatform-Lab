# ===================================
# Function App Outputs
# ===================================

output "function_app_id" {
  description = "ID of the Function App"
  value       = azurerm_function_app_flex_consumption.function.id
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_function_app_flex_consumption.function.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_function_app_flex_consumption.function.default_hostname
}

output "function_app_outbound_ip_addresses" {
  description = "Outbound IP addresses of the Function App"
  value       = azurerm_function_app_flex_consumption.function.outbound_ip_addresses
}

output "function_app_possible_outbound_ip_addresses" {
  description = "Possible outbound IP addresses of the Function App"
  value       = azurerm_function_app_flex_consumption.function.possible_outbound_ip_addresses
}

output "function_app_principal_id" {
  description = "Principal ID of the Function App managed identity"
  value       = azurerm_function_app_flex_consumption.function.identity[0].principal_id
}

output "function_app_tenant_id" {
  description = "Tenant ID of the Function App managed identity"
  value       = azurerm_function_app_flex_consumption.function.identity[0].tenant_id
}

# ===================================
# Service Plan Outputs
# ===================================

output "service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.function.id
}

output "service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.function.name
}

# ===================================
# Application Insights Outputs
# ===================================

output "app_insights_id" {
  description = "ID of the Application Insights instance"
  value       = azurerm_application_insights.function.id
}

output "app_insights_name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.function.name
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation key of the Application Insights instance"
  value       = azurerm_application_insights.function.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection string of the Application Insights instance"
  value       = azurerm_application_insights.function.connection_string
  sensitive   = true
}
