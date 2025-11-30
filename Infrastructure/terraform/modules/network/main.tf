# ===================================
# Virtual Network
# ===================================

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

# ===================================
# Subnets
# ===================================

resource "azurerm_subnet" "powerplatform" {
  name                 = var.subnet_powerplatform_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_powerplatform_address_prefixes

  # Service endpoints for Key Vault and Storage access
  service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]

  # Optional: Delegation for Power Platform enterprise policies
  # Enable this when using Power Platform VNet integration
  dynamic "delegation" {
    for_each = var.enable_powerplatform_delegation ? [1] : []
    content {
      name = "powerplatform-delegation"

      service_delegation {
        name = "Microsoft.PowerPlatform/enterprisePolicies"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ]
      }
    }
  }
}

resource "azurerm_subnet" "logicapps" {
  name                 = var.subnet_logicapps_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_logicapps_address_prefixes

  # Service endpoints for Storage and Key Vault access
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "apim" {
  name                 = var.subnet_apim_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_apim_address_prefixes

  # Service endpoints for Storage, Web (Function Apps), and Key Vault access
  service_endpoints = ["Microsoft.Storage", "Microsoft.Web", "Microsoft.KeyVault"]
}

resource "azurerm_subnet" "fn" {
  name                 = var.subnet_fn_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_fn_address_prefixes

  # Service endpoints for Storage and Key Vault access
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]

  delegation {
    name = "delegation"

    service_delegation {
      # For Azure Functions Flex Consumption plan
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

resource "azurerm_subnet" "storage" {
  name                 = var.subnet_storage_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_storage_address_prefixes

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "nat" {
  name                 = var.subnet_nat_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_nat_address_prefixes
}

# ===================================
# Network Security Groups
# ===================================

resource "azurerm_network_security_group" "powerplatform" {
  name                = "${var.subnet_powerplatform_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "logicapps" {
  name                = "${var.subnet_logicapps_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "apim" {
  name                = "${var.subnet_apim_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "fn" {
  name                = "${var.subnet_fn_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "storage" {
  name                = "${var.subnet_storage_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ===================================
# NSG - Subnet Associations
# ===================================

resource "azurerm_subnet_network_security_group_association" "powerplatform" {
  subnet_id                 = azurerm_subnet.powerplatform.id
  network_security_group_id = azurerm_network_security_group.powerplatform.id
}

resource "azurerm_subnet_network_security_group_association" "logicapps" {
  subnet_id                 = azurerm_subnet.logicapps.id
  network_security_group_id = azurerm_network_security_group.logicapps.id
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

resource "azurerm_subnet_network_security_group_association" "fn" {
  subnet_id                 = azurerm_subnet.fn.id
  network_security_group_id = azurerm_network_security_group.fn.id
}

resource "azurerm_subnet_network_security_group_association" "storage" {
  subnet_id                 = azurerm_subnet.storage.id
  network_security_group_id = azurerm_network_security_group.storage.id
}

# ===================================
# NSG Rules - PowerPlatform Subnet
# ===================================

# Allow traffic from PowerPlatform to Logic Apps
resource "azurerm_network_security_rule" "powerplatform_to_logicapps_outbound" {
  name                        = "Allow-PowerPlatform-To-LogicApps-Outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.subnet_powerplatform_address_prefixes
  destination_address_prefixes = var.subnet_logicapps_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.powerplatform.name
}

# Allow traffic from Logic Apps to PowerPlatform
resource "azurerm_network_security_rule" "powerplatform_from_logicapps_inbound" {
  name                        = "Allow-LogicApps-To-PowerPlatform-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefixes = var.subnet_powerplatform_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.powerplatform.name
}

# ===================================
# NSG Rules - Logic Apps Subnet
# ===================================

# Allow traffic from Logic Apps to PowerPlatform
resource "azurerm_network_security_rule" "logicapps_to_powerplatform_outbound" {
  name                        = "Allow-LogicApps-To-PowerPlatform-Outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefixes = var.subnet_powerplatform_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# Allow traffic from PowerPlatform to Logic Apps
resource "azurerm_network_security_rule" "logicapps_from_powerplatform_inbound" {
  name                        = "Allow-PowerPlatform-To-LogicApps-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.subnet_powerplatform_address_prefixes
  destination_address_prefixes = var.subnet_logicapps_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# Allow traffic from Logic Apps to APIM
resource "azurerm_network_security_rule" "logicapps_to_apim_outbound" {
  name                        = "Allow-LogicApps-To-APIM-Outbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefixes = var.subnet_apim_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# Allow traffic from PowerPlatform to APIM
resource "azurerm_network_security_rule" "powerplatform_to_apim_outbound" {
  name                        = "Allow-PowerPlatform-To-APIM-Outbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "80"]
  source_address_prefixes     = var.subnet_powerplatform_address_prefixes
  destination_address_prefixes = var.subnet_apim_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.powerplatform.name
}

# Allow traffic from Logic Apps to Storage
resource "azurerm_network_security_rule" "logicapps_to_storage_outbound" {
  name                        = "Allow-LogicApps-To-Storage-Outbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefixes = var.subnet_storage_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# Allow Logic Apps to communicate with Azure Monitor (Application Insights, health checks, diagnostics)
resource "azurerm_network_security_rule" "logicapps_to_azuremonitor_outbound" {
  name                        = "Allow-LogicApps-To-AzureMonitor-Outbound"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# Allow Logic Apps to communicate with Azure Resource Manager (control plane operations)
resource "azurerm_network_security_rule" "logicapps_to_arm_outbound" {
  name                        = "Allow-LogicApps-To-ARM-Outbound"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefix  = "AzureResourceManager"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# Allow Logic Apps to access Azure Storage service tag (for extension bundles, platform operations)
resource "azurerm_network_security_rule" "logicapps_to_azurestorage_outbound" {
  name                        = "Allow-LogicApps-To-AzureStorage-Outbound"
  priority                    = 150
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefix  = "Storage"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# Allow Logic Apps to reach external internet endpoints (Dataverse, third-party APIs)
resource "azurerm_network_security_rule" "logicapps_to_internet_outbound" {
  name                        = "Allow-LogicApps-To-Internet-Outbound"
  priority                    = 160
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "80"]
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.logicapps.name
}

# ===================================
# NSG Rules - APIM Subnet
# ===================================

# Allow traffic from Logic Apps to APIM
resource "azurerm_network_security_rule" "apim_from_logicapps_inbound" {
  name                        = "Allow-LogicApps-To-APIM-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefixes = var.subnet_apim_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# Allow traffic from PowerPlatform to APIM
resource "azurerm_network_security_rule" "apim_from_powerplatform_inbound" {
  name                        = "Allow-PowerPlatform-To-APIM-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "80"]
  source_address_prefixes     = var.subnet_powerplatform_address_prefixes
  destination_address_prefixes = var.subnet_apim_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# Allow traffic from APIM to Functions
resource "azurerm_network_security_rule" "apim_to_fn_outbound" {
  name                        = "Allow-APIM-To-Functions-Outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_apim_address_prefixes
  destination_address_prefixes = var.subnet_fn_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# ===================================
# NSG Rules - APIM Management (Required for Internal VNet)
# ===================================
# Reference: https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet

# Allow Azure Infrastructure Load Balancer (required for health probes)
resource "azurerm_network_security_rule" "apim_azure_lb_inbound" {
  name                        = "Allow-AzureLoadBalancer-Inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefixes = var.subnet_apim_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# Allow management endpoint access on port 3443 (for control plane)
resource "azurerm_network_security_rule" "apim_management_inbound" {
  name                        = "Allow-ApiManagement-ControlPlane"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3443"
  source_address_prefix       = "ApiManagement"
  destination_address_prefixes = var.subnet_apim_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# Allow Azure Storage access (required for APIM configuration storage)
resource "azurerm_network_security_rule" "apim_storage_outbound" {
  name                        = "Allow-Storage-Outbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_apim_address_prefixes
  destination_address_prefix  = "Storage"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# Allow Azure SQL access (required for APIM internal database)
resource "azurerm_network_security_rule" "apim_sql_outbound" {
  name                        = "Allow-AzureSQL-Outbound"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefixes     = var.subnet_apim_address_prefixes
  destination_address_prefix  = "Sql"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# Allow Azure Key Vault access (required for certificates and secrets)
resource "azurerm_network_security_rule" "apim_keyvault_outbound" {
  name                        = "Allow-AzureKeyVault-Outbound"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_apim_address_prefixes
  destination_address_prefix  = "AzureKeyVault"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# ===================================
# NSG Rules - Functions Subnet
# ===================================

# Allow traffic from APIM to Functions
resource "azurerm_network_security_rule" "fn_from_apim_inbound" {
  name                        = "Allow-APIM-To-Functions-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_apim_address_prefixes
  destination_address_prefixes = var.subnet_fn_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# Allow traffic from Functions to Storage
resource "azurerm_network_security_rule" "fn_to_storage_outbound" {
  name                        = "Allow-Functions-To-Storage-Outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_fn_address_prefixes
  destination_address_prefixes = var.subnet_storage_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# Allow Azure Functions to communicate with Azure Monitor (health checks and monitoring)
resource "azurerm_network_security_rule" "fn_to_azuremonitor_outbound" {
  name                        = "Allow-Functions-To-AzureMonitor-Outbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_fn_address_prefixes
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# Allow Azure Functions to access Azure Storage service tag (for runtime and images)
resource "azurerm_network_security_rule" "fn_to_azurestorage_outbound" {
  name                        = "Allow-Functions-To-AzureStorage-Outbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_fn_address_prefixes
  destination_address_prefix  = "Storage"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# Allow Azure Functions to access Azure Container Registry (for pulling container images)
resource "azurerm_network_security_rule" "fn_to_acr_outbound" {
  name                        = "Allow-Functions-To-ACR-Outbound"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_fn_address_prefixes
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# Allow Azure Functions to communicate with Azure Resource Manager (control plane)
resource "azurerm_network_security_rule" "fn_to_arm_outbound" {
  name                        = "Allow-Functions-To-ARM-Outbound"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_fn_address_prefixes
  destination_address_prefix  = "AzureResourceManager"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# Allow Azure Load Balancer health probes to Functions (required for health checks)
resource "azurerm_network_security_rule" "fn_from_azurelb_inbound" {
  name                        = "Allow-AzureLoadBalancer-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefixes = var.subnet_fn_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# Allow Azure Functions Flex Consumption to communicate with management services
resource "azurerm_network_security_rule" "fn_to_internet_outbound" {
  name                        = "Allow-Functions-To-Internet-Outbound"
  priority                    = 150
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.subnet_fn_address_prefixes
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.fn.name
}

# ===================================
# NSG Rules - Storage Subnet
# ===================================

# Allow traffic from Logic Apps to Storage
resource "azurerm_network_security_rule" "storage_from_logicapps_inbound" {
  name                        = "Allow-LogicApps-To-Storage-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_logicapps_address_prefixes
  destination_address_prefixes = var.subnet_storage_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.storage.name
}

# Allow traffic from Functions to Storage
resource "azurerm_network_security_rule" "storage_from_fn_inbound" {
  name                        = "Allow-Functions-To-Storage-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.subnet_fn_address_prefixes
  destination_address_prefixes = var.subnet_storage_address_prefixes
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.storage.name
}

# ===================================
# NAT Gateway with Static Public IP
# ===================================

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "${var.vnet_name}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.nat_gateway_zones
  tags                = var.tags
}

# NAT Gateway
resource "azurerm_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  name                    = "${var.vnet_name}-nat-gw"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = var.nat_gateway_idle_timeout
  zones                   = var.nat_gateway_zones
  tags                    = var.tags
}

# Associate Public IP with NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

# Associate NAT Gateway with Logic Apps subnet for outbound internet traffic
resource "azurerm_subnet_nat_gateway_association" "logicapps" {
  count = var.enable_nat_gateway ? 1 : 0

  subnet_id      = azurerm_subnet.logicapps.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

# Associate NAT Gateway with Functions subnet for outbound internet traffic
resource "azurerm_subnet_nat_gateway_association" "fn" {
  count = var.enable_nat_gateway ? 1 : 0

  subnet_id      = azurerm_subnet.fn.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

# Optional: Associate NAT Gateway with NAT subnet if needed
resource "azurerm_subnet_nat_gateway_association" "nat" {
  count = var.enable_nat_gateway && var.enable_nat_subnet_association ? 1 : 0

  subnet_id      = azurerm_subnet.nat.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
