# ===================================
# Storage Account Outputs
# ===================================

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "primary_connection_string" {
  description = "Primary connection string of the storage account"
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
}

output "secondary_connection_string" {
  description = "Secondary connection string of the storage account"
  value       = azurerm_storage_account.this.secondary_connection_string
  sensitive   = true
}

output "primary_access_key" {
  description = "Primary access key of the storage account"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "secondary_access_key" {
  description = "Secondary access key of the storage account"
  value       = azurerm_storage_account.this.secondary_access_key
  sensitive   = true
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_queue_endpoint" {
  description = "Primary queue endpoint of the storage account"
  value       = azurerm_storage_account.this.primary_queue_endpoint
}

output "primary_table_endpoint" {
  description = "Primary table endpoint of the storage account"
  value       = azurerm_storage_account.this.primary_table_endpoint
}

output "primary_file_endpoint" {
  description = "Primary file endpoint of the storage account"
  value       = azurerm_storage_account.this.primary_file_endpoint
}
