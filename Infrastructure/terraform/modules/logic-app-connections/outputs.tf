# ===================================
# Connection Outputs
# ===================================

output "dataverse_connection_id" {
  description = "Dataverse connection ID"
  value       = var.create_dataverse_connection ? azapi_resource.commondataservice[0].id : null
}

output "dataverse_connection_name" {
  description = "Dataverse connection name"
  value       = var.create_dataverse_connection ? azapi_resource.commondataservice[0].name : null
}

output "dataverse_connection_runtime_url" {
  description = "Dataverse connection runtime URL - retrieved from connection properties"
  # The runtime URL is read directly from the API connection's properties
  # This is exported via response_export_values in the azapi_resource
  # Format: https://{region}.logic.azure.com:443/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Web/connections/{name}
  value       = var.create_dataverse_connection ? jsondecode(azapi_resource.commondataservice[0].output).properties.connectionRuntimeUrl : null
}

output "keyvault_connection_id" {
  description = "Key Vault connection ID"
  value       = var.create_keyvault_connection ? azurerm_api_connection.keyvault[0].id : null
}

output "keyvault_connection_name" {
  description = "Key Vault connection name"
  value       = var.create_keyvault_connection ? azurerm_api_connection.keyvault[0].name : null
}

output "custom_api_connection_id" {
  description = "Custom API connection ID"
  value       = var.create_custom_api_connection ? azurerm_api_connection.custom_api[0].id : null
}

output "custom_api_connection_name" {
  description = "Custom API connection name"
  value       = var.create_custom_api_connection ? azurerm_api_connection.custom_api[0].name : null
}

# ===================================
# Connection Parameters for Logic App
# ===================================

# This output provides the $connections parameter structure for Logic Apps
output "logic_app_connections_parameter" {
  description = "Connections parameter for Logic App workflow"
  value = {
    commondataservice = var.create_dataverse_connection ? {
      id             = azapi_resource.commondataservice[0].id
      connectionId   = azapi_resource.commondataservice[0].id
      connectionName = azapi_resource.commondataservice[0].name
      connectionProperties = {
        authentication = {
          type = "ManagedServiceIdentity"
        }
      }
    } : null

    keyvault = var.create_keyvault_connection ? {
      id             = azurerm_api_connection.keyvault[0].id
      connectionId   = azurerm_api_connection.keyvault[0].id
      connectionName = azurerm_api_connection.keyvault[0].name
      connectionProperties = {
        authentication = {
          type = "ManagedServiceIdentity"
        }
      }
    } : null

    customapi = var.create_custom_api_connection ? {
      id             = azurerm_api_connection.custom_api[0].id
      connectionId   = azurerm_api_connection.custom_api[0].id
      connectionName = azurerm_api_connection.custom_api[0].name
    } : null
  }
}
