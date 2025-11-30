# ===================================
# Outputs
# ===================================

output "id" {
  description = "The system ID of the enterprise policy (used for linking to Power Platform environments)"
  value       = azapi_resource.enterprise_policy.output.properties.systemId
}

output "azure_resource_id" {
  description = "The Azure Resource Manager ID of the enterprise policy"
  value       = azapi_resource.enterprise_policy.id
}

output "name" {
  description = "The name of the enterprise policy"
  value       = azapi_resource.enterprise_policy.name
}

output "location" {
  description = "The location of the enterprise policy"
  value       = azapi_resource.enterprise_policy.location
}

output "subnet_ids" {
  description = "The subnet IDs used for network injection across paired regions"
  value       = [for subnet in var.subnets : subnet.id]
}

output "policy_type" {
  description = "The type of enterprise policy"
  value       = "NetworkInjection"
}
