# ===================================
# Private DNS Zone for API Management
# ===================================

# Local value to extract hostname from APIM gateway URL
# gateway_url format: https://hostname.azure-api.net
# We need just the hostname part for the Private DNS Zone
locals {
  apim_gateway_hostname = var.enable_api_management && var.apim_virtual_network_type == "Internal" ? trim(replace(module.api_management[0].gateway_url, "https://", ""), "/") : ""
}

# Create Private DNS Zone for the specific APIM hostname only
# This prevents DNS conflicts with other *.azure-api.net domains (e.g., Microsoft's Dataverse connector infrastructure)
# By using a specific hostname zone instead of the broad "azure-api.net", we ensure:
# - Internal APIM resolves to private IP
# - All other *.azure-api.net domains resolve via public DNS (no interference)
resource "azurerm_private_dns_zone" "apim" {
  count = var.enable_api_management && var.apim_virtual_network_type == "Internal" ? 1 : 0

  name                = local.apim_gateway_hostname
  resource_group_name = module.resource_groups["network"].name

  tags = merge(
    local.common_tags,
    {
      Component = "Private DNS"
      Purpose   = "DNS resolution for internal API Management (specific hostname only)"
    }
  )

  depends_on = [module.resource_groups, module.api_management]
}

# Link Private DNS Zone to West Europe VNet
resource "azurerm_private_dns_zone_virtual_network_link" "apim_westeurope" {
  count = var.enable_api_management && var.apim_virtual_network_type == "Internal" ? 1 : 0

  name                  = "apim-dns-link-westeurope"
  resource_group_name   = module.resource_groups["network"].name
  private_dns_zone_name = azurerm_private_dns_zone.apim[0].name
  virtual_network_id    = module.network.vnet_id
  registration_enabled  = false

  tags = merge(
    local.common_tags,
    {
      Component = "Private DNS"
      Purpose   = "Link Private DNS to West Europe VNet"
    }
  )

  depends_on = [azurerm_private_dns_zone.apim, module.network]
}

# Link Private DNS Zone to North Europe VNet (when Power Platform delegation is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "apim_northeurope" {
  count = var.enable_api_management && var.apim_virtual_network_type == "Internal" && var.enable_powerplatform_subnet_delegation ? 1 : 0

  name                  = "apim-dns-link-northeurope"
  resource_group_name   = module.resource_groups["network"].name
  private_dns_zone_name = azurerm_private_dns_zone.apim[0].name
  virtual_network_id    = azurerm_virtual_network.northeurope[0].id
  registration_enabled  = false

  tags = merge(
    local.common_tags,
    {
      Component = "Private DNS"
      Purpose   = "Link Private DNS to North Europe VNet for Power Platform"
    }
  )

  depends_on = [azurerm_private_dns_zone.apim, azurerm_virtual_network.northeurope]
}

# ===================================
# API Management
# ===================================

# Public IP for API Management (required for External VNet mode with stv2 platform)
resource "azurerm_public_ip" "apim" {
  count = var.enable_api_management && var.apim_virtual_network_type == "External" && var.apim_enable_public_endpoint ? 1 : 0

  name                = "${var.environment}-${var.project_name}-apim-pip-${local.region_short}"
  location            = module.resource_groups["network"].location
  resource_group_name = module.resource_groups["network"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.environment}-${lower(var.project_name)}-apim-${local.random_suffix}"

  tags = merge(
    local.common_tags,
    {
      Component = "API Management"
      Purpose   = "Public IP for API Management external access"
    }
  )

  depends_on = [module.resource_groups]
}

# API Management instance with VNet integration
module "api_management" {
  source = "./modules/api-management"

  count = var.enable_api_management ? 1 : 0

  # Include random suffix for global uniqueness (required even for Internal mode)
  # APIM names must be globally unique across Azure as they get *.azure-api.net subdomains
  name                = "${var.environment}-${var.project_name}-apim-${local.region_short}-${local.random_suffix}"
  resource_group_name = module.resource_groups["network"].name
  location            = module.resource_groups["network"].location
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name
  virtual_network_type = var.apim_virtual_network_type

  # Integrate with subnet-apim
  subnet_id            = module.network.subnet_apim_id
  public_ip_address_id = var.apim_virtual_network_type == "External" && var.apim_enable_public_endpoint ? azurerm_public_ip.apim[0].id : ""

  # Disable public network access by default for security
  public_network_access_enabled = var.apim_enable_public_endpoint

  # BFF API configuration
  enable_bff_api        = var.apim_enable_bff_api
  bff_openapi_spec_path = var.apim_bff_openapi_spec_path != "" ? var.apim_bff_openapi_spec_path : "${path.module}/bff-openapi/pp-bff.json"
  bff_backend_url       = "https://${module.function_app.function_app_default_hostname}/api"
  oauth_tenant_id       = data.azurerm_client_config.current.tenant_id
  oauth_audience        = "api://${module.app_registrations[var.apim_oauth_audience_app_registration].client_id}"
  tags = merge(
    local.common_tags,
    {
      Component = "API Management"
      Purpose   = "API gateway for Power Platform and Azure integrations"
    }
  )

  depends_on = [module.resource_groups, module.network, azurerm_public_ip.apim, module.function_app]
}

# ===================================
# Private DNS A Record for API Management
# ===================================

# Create DNS A record for APIM gateway endpoint (apex/root record)
# Since the Private DNS Zone name is the full APIM hostname (e.g., dev-pplab01-apim-weu-c79b.azure-api.net),
# we use "@" to create an apex record that maps the zone name itself to the private IP
resource "azurerm_private_dns_a_record" "apim_gateway" {
  count = var.enable_api_management && var.apim_virtual_network_type == "Internal" ? 1 : 0

  # "@" represents the apex/root of the zone (the zone name itself)
  name                = "@"
  zone_name           = azurerm_private_dns_zone.apim[0].name
  resource_group_name = module.resource_groups["network"].name
  ttl                 = 300
  records             = [module.api_management[0].private_ip_addresses[0]]

  tags = merge(
    local.common_tags,
    {
      Component = "Private DNS"
      Purpose   = "DNS A record for APIM gateway (resolves to private IP)"
    }
  )

  depends_on = [azurerm_private_dns_zone.apim, module.api_management]
}
