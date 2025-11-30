# ===================================
# Virtual Network Outputs
# ===================================

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.this.address_space
}

# ===================================
# Subnet Outputs
# ===================================

output "subnet_powerplatform_id" {
  description = "ID of the Power Platform subnet"
  value       = azurerm_subnet.powerplatform.id
}

output "subnet_powerplatform_name" {
  description = "Name of the Power Platform subnet"
  value       = azurerm_subnet.powerplatform.name
}

output "subnet_powerplatform_address_prefixes" {
  description = "Address prefixes of the Power Platform subnet"
  value       = azurerm_subnet.powerplatform.address_prefixes
}

output "subnet_logicapps_id" {
  description = "ID of the Logic Apps subnet"
  value       = azurerm_subnet.logicapps.id
}

output "subnet_logicapps_name" {
  description = "Name of the Logic Apps subnet"
  value       = azurerm_subnet.logicapps.name
}

output "subnet_logicapps_address_prefixes" {
  description = "Address prefixes of the Logic Apps subnet"
  value       = azurerm_subnet.logicapps.address_prefixes
}

output "subnet_apim_id" {
  description = "ID of the API Management subnet"
  value       = azurerm_subnet.apim.id
}

output "subnet_apim_name" {
  description = "Name of the API Management subnet"
  value       = azurerm_subnet.apim.name
}

output "subnet_apim_address_prefixes" {
  description = "Address prefixes of the API Management subnet"
  value       = azurerm_subnet.apim.address_prefixes
}

output "subnet_fn_id" {
  description = "ID of the Functions subnet"
  value       = azurerm_subnet.fn.id
}

output "subnet_fn_name" {
  description = "Name of the Functions subnet"
  value       = azurerm_subnet.fn.name
}

output "subnet_fn_address_prefixes" {
  description = "Address prefixes of the Functions subnet"
  value       = azurerm_subnet.fn.address_prefixes
}

output "subnet_storage_id" {
  description = "ID of the Storage subnet"
  value       = azurerm_subnet.storage.id
}

output "subnet_storage_name" {
  description = "Name of the Storage subnet"
  value       = azurerm_subnet.storage.name
}

output "subnet_storage_address_prefixes" {
  description = "Address prefixes of the Storage subnet"
  value       = azurerm_subnet.storage.address_prefixes
}

output "subnet_nat_id" {
  description = "ID of the NAT Gateway subnet"
  value       = azurerm_subnet.nat.id
}

output "subnet_nat_name" {
  description = "Name of the NAT Gateway subnet"
  value       = azurerm_subnet.nat.name
}

output "subnet_nat_address_prefixes" {
  description = "Address prefixes of the NAT Gateway subnet"
  value       = azurerm_subnet.nat.address_prefixes
}

# ===================================
# Network Security Group Outputs
# ===================================

output "nsg_powerplatform_id" {
  description = "ID of the Power Platform NSG"
  value       = azurerm_network_security_group.powerplatform.id
}

output "nsg_logicapps_id" {
  description = "ID of the Logic Apps NSG"
  value       = azurerm_network_security_group.logicapps.id
}

output "nsg_apim_id" {
  description = "ID of the API Management NSG"
  value       = azurerm_network_security_group.apim.id
}

output "nsg_fn_id" {
  description = "ID of the Functions NSG"
  value       = azurerm_network_security_group.fn.id
}

output "nsg_storage_id" {
  description = "ID of the Storage NSG"
  value       = azurerm_network_security_group.storage.id
}

# ===================================
# NAT Gateway Outputs
# ===================================

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (null if disabled)"
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.this[0].id : null
}

output "nat_gateway_name" {
  description = "Name of the NAT Gateway (null if disabled)"
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.this[0].name : null
}

output "nat_public_ip_address" {
  description = "Static public IP address of the NAT Gateway (null if disabled)"
  value       = var.enable_nat_gateway ? azurerm_public_ip.nat[0].ip_address : null
}

output "nat_public_ip_id" {
  description = "ID of the NAT Gateway public IP (null if disabled)"
  value       = var.enable_nat_gateway ? azurerm_public_ip.nat[0].id : null
}
