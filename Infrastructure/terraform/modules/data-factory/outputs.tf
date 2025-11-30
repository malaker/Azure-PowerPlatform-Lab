# ===================================
# Data Factory Outputs
# ===================================

output "data_factory_id" {
  description = "Data Factory resource ID"
  value       = azurerm_data_factory.this.id
}

output "data_factory_name" {
  description = "Data Factory name"
  value       = azurerm_data_factory.this.name
}

output "data_factory_principal_id" {
  description = "Data Factory managed identity principal ID"
  value       = azurerm_data_factory.this.identity[0].principal_id
}

output "data_factory_tenant_id" {
  description = "Data Factory managed identity tenant ID"
  value       = azurerm_data_factory.this.identity[0].tenant_id
}

output "integration_runtime_name" {
  description = "Managed VNet integration runtime name"
  value       = var.enable_managed_vnet ? azurerm_data_factory_integration_runtime_azure.managed_vnet[0].name : null
}

output "keyvault_linked_service_name" {
  description = "Key Vault linked service name"
  value       = length(azurerm_data_factory_linked_service_key_vault.this) > 0 ? azurerm_data_factory_linked_service_key_vault.this["enabled"].name : null
}

output "storage_linked_service_name" {
  description = "Storage linked service name"
  value       = length(azurerm_data_factory_linked_service_azure_blob_storage.this) > 0 ? azurerm_data_factory_linked_service_azure_blob_storage.this["enabled"].name : null
}

output "dataverse_linked_service_name" {
  description = "Dataverse linked service name"
  value       = length(azurerm_data_factory_linked_custom_service.dataverse) > 0 ? azurerm_data_factory_linked_custom_service.dataverse["enabled"].name : null
}

output "apim_linked_service_name" {
  description = "APIM linked service name"
  value       = length(azurerm_data_factory_linked_custom_service.apim) > 0 ? azurerm_data_factory_linked_custom_service.apim["enabled"].name : null
}

output "resource_group_name" {
  description = "Resource group name"
  value       = var.resource_group_name
}
