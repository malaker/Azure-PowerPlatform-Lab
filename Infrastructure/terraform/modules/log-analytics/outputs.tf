# ===================================
# Log Analytics Workspace Outputs
# ===================================

output "workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_primary_shared_key" {
  description = "Primary shared key of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive   = true
}

output "workspace_secondary_shared_key" {
  description = "Secondary shared key of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.this.secondary_shared_key
  sensitive   = true
}

output "workspace_customer_id" {
  description = "Workspace (Customer) ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
