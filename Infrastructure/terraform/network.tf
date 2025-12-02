# ===================================
# Network Watcher
# ===================================

# Resource group for Network Watcher resources
# Azure automatically creates NetworkWatcherRG, but managing it in Terraform ensures proper cleanup
resource "azurerm_resource_group" "network_watcher" {
  name     = "NetworkWatcherRG"
  location = local.current_env_config.location

  tags = merge(
    local.common_tags,
    {
      Purpose = "Network Watcher resources for monitoring and diagnostics"
    }
  )

  lifecycle {
    # Prevent recreation if Azure auto-creates it
    ignore_changes = [
      tags,
      location  # Azure might create it in different location
    ]
  }
}

# Create Network Watcher for West Europe (primary region)
# Azure creates these automatically, but managing them in Terraform ensures proper cleanup
resource "azurerm_network_watcher" "westeurope" {
  name                = "NetworkWatcher_westeurope"
  location            = local.current_env_config.location
  resource_group_name = azurerm_resource_group.network_watcher.name
  tags                = local.common_tags

  lifecycle {
    # Prevent recreation if Azure auto-creates it
    ignore_changes = [
      tags
    ]
  }

  depends_on = [azurerm_resource_group.network_watcher]
}

# Create Network Watcher for North Europe (paired region) - only when using enterprise policy
resource "azurerm_network_watcher" "northeurope" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                = "NetworkWatcher_northeurope"
  location            = local.current_env_config.backup_location
  resource_group_name = azurerm_resource_group.network_watcher.name
  tags                = local.common_tags

  lifecycle {
    # Prevent recreation if Azure auto-creates it
    ignore_changes = [
      tags
    ]
  }

  depends_on = [azurerm_resource_group.network_watcher]
}

# ===================================
# Networking
# ===================================

# Create VNet, Subnets, NSGs, NSG Rules, and NAT Gateway
module "network" {
  source = "./modules/network"

  vnet_name           = "${var.environment}-${var.project_name}-vnet-${local.region_short}"
  resource_group_name = module.resource_groups["network"].name
  location            = module.resource_groups["network"].location
  address_space       = ["10.0.0.0/16"]

  # Subnet configuration
  subnet_powerplatform_name             = "subnet-powerplatform"
  subnet_powerplatform_address_prefixes = ["10.0.1.0/24"]

  subnet_logicapps_name             = "subnet-logicapps"
  subnet_logicapps_address_prefixes = ["10.0.2.0/24"]

  # Enable Power Platform delegation on subnet-powerplatform when enterprise policy is enabled
  enable_powerplatform_delegation = var.enable_powerplatform_subnet_delegation

  subnet_apim_name             = "subnet-apim"
  subnet_apim_address_prefixes = ["10.0.3.0/24"]

  subnet_fn_name             = "subnet-functions"
  subnet_fn_address_prefixes = ["10.0.4.0/24"]

  subnet_storage_name             = "subnet-storage"
  subnet_storage_address_prefixes = ["10.0.5.0/24"]

  subnet_nat_name             = "subnet-nat"
  subnet_nat_address_prefixes = ["10.0.6.0/24"]

  # NAT Gateway configuration
  enable_nat_gateway            = var.enable_nat_gateway
  nat_gateway_idle_timeout      = 10
  nat_gateway_zones             = ["1"] # NAT Gateway only supports a single zone
  enable_nat_subnet_association = false

  tags = merge(
    local.common_tags,
    {
      Component = "Network"
    }
  )

  depends_on = [module.resource_groups]
}

# North Europe VNet (paired region for Power Platform Enterprise Policy)
# Simplified configuration with only Power Platform subnet
resource "azurerm_virtual_network" "northeurope" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                = "${var.environment}-${var.project_name}-vnet-neu"
  location            = module.resource_group_network_northeurope[0].location
  resource_group_name = module.resource_group_network_northeurope[0].name
  address_space       = ["10.1.0.0/16"]

  tags = merge(
    local.common_tags,
    {
      Component = "Network"
      Purpose   = "North Europe paired region for Power Platform"
      Region    = "northeurope"
    }
  )

  depends_on = [module.resource_group_network_northeurope]
}

# Power Platform subnet in North Europe with delegation
resource "azurerm_subnet" "northeurope_powerplatform" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                 = "subnet-powerplatform"
  resource_group_name  = module.resource_group_network_northeurope[0].name
  virtual_network_name = azurerm_virtual_network.northeurope[0].name
  address_prefixes     = ["10.1.1.0/24"]

  # Service endpoints for Key Vault and Storage access
  service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage", "Microsoft.Web"]

  delegation {
    name = "powerplatform-delegation"

    service_delegation {
      name = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  depends_on = [azurerm_virtual_network.northeurope]
}

# Network Security Group for North Europe Power Platform subnet
resource "azurerm_network_security_group" "northeurope_powerplatform" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                = "${var.environment}-${var.project_name}-nsg-powerplatform-neu"
  location            = module.resource_group_network_northeurope[0].location
  resource_group_name = module.resource_group_network_northeurope[0].name

  tags = merge(
    local.common_tags,
    {
      Component = "Network Security"
      Purpose   = "Power Platform subnet protection"
      Region    = "northeurope"
    }
  )

  depends_on = [module.resource_group_network_northeurope]
}

# Associate NSG with Power Platform subnet
resource "azurerm_subnet_network_security_group_association" "northeurope_powerplatform" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  subnet_id                 = azurerm_subnet.northeurope_powerplatform[0].id
  network_security_group_id = azurerm_network_security_group.northeurope_powerplatform[0].id

  depends_on = [azurerm_subnet.northeurope_powerplatform, azurerm_network_security_group.northeurope_powerplatform]
}

# NSG Rule: Allow outbound from North Europe Power Platform to West Europe APIM
resource "azurerm_network_security_rule" "northeurope_powerplatform_to_apim" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                        = "Allow-PowerPlatform-to-APIM"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "80"]
  source_address_prefix       = "10.1.1.0/24"  # North Europe Power Platform subnet
  destination_address_prefix  = "10.0.3.0/24"  # West Europe APIM subnet
  resource_group_name         = module.resource_group_network_northeurope[0].name
  network_security_group_name = azurerm_network_security_group.northeurope_powerplatform[0].name

  depends_on = [azurerm_network_security_group.northeurope_powerplatform]
}

# NSG Rule: Allow inbound from North Europe Power Platform to West Europe APIM
resource "azurerm_network_security_rule" "apim_from_northeurope_powerplatform" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                        = "Allow-From-PowerPlatform-NorthEurope"
  priority                    = 125
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "80"]
  source_address_prefix       = "10.1.1.0/24"  # North Europe Power Platform subnet
  destination_address_prefix  = "10.0.3.0/24"  # West Europe APIM subnet
  resource_group_name         = module.resource_groups["network"].name
  network_security_group_name = "${module.network.subnet_apim_name}-nsg"

  depends_on = [module.network]
}

# ===================================
# VNet Peering (West Europe <-> North Europe)
# ===================================

# VNet peering from West Europe to North Europe
resource "azurerm_virtual_network_peering" "westeurope_to_northeurope" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                      = "peer-weu-to-neu"
  resource_group_name       = module.resource_groups["network"].name
  virtual_network_name      = module.network.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.northeurope[0].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [module.network, azurerm_virtual_network.northeurope]
}

# VNet peering from North Europe to West Europe
resource "azurerm_virtual_network_peering" "northeurope_to_westeurope" {
  count = var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                      = "peer-neu-to-weu"
  resource_group_name       = module.resource_group_network_northeurope[0].name
  virtual_network_name      = azurerm_virtual_network.northeurope[0].name
  remote_virtual_network_id = module.network.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [module.network, azurerm_virtual_network.northeurope]
}
