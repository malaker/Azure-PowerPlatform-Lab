# ===================================
# Azure API Management
# ===================================

resource "azurerm_api_management" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  sku_name = var.sku_name

  # VNet integration configuration
  dynamic "virtual_network_configuration" {
    for_each = var.virtual_network_type != "None" && var.subnet_id != "" ? [1] : []
    content {
      subnet_id = var.subnet_id
    }
  }

  virtual_network_type = var.virtual_network_type

  # Public IP for external VNet mode (required for stv2 platform)
  public_ip_address_id = var.virtual_network_type == "External" && var.public_ip_address_id != "" ? var.public_ip_address_id : null

  # Note: public_network_access_enabled cannot be set to false during creation
  # It must be disabled after the APIM is created via a separate update
  # For now, we leave it enabled during creation - disable manually or via lifecycle

  # Identity for managed identity scenarios
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ===================================
# BFF API (Backend for Frontend)
# ===================================

# API definition from OpenAPI specification
resource "azurerm_api_management_api" "bff" {
  count = var.enable_bff_api ? 1 : 0

  name                = "pp-bff-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "Power Platform BFF API"
  path                = "bff"
  protocols           = ["https"]
  service_url         = var.bff_backend_url

  # Disable subscription requirement for calls from Power Platform
  subscription_required = false

  import {
    content_format = "swagger-json"
    content_value  = file(var.bff_openapi_spec_path)
  }
}

# Policy to validate OAuth 2.0 JWT tokens and forward to backend
resource "azurerm_api_management_api_policy" "bff" {
  count = var.enable_bff_api ? 1 : 0

  api_name            = azurerm_api_management_api.bff[0].name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <!-- Check if Authorization header is present -->
    <check-header name="Authorization" failed-check-httpcode="401" failed-check-error-message="Unauthorized. Authorization header is required." ignore-case="true">
      <value>Bearer</value>
    </check-header>
    <!-- Validate JWT token -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Access token is missing or invalid.">
      <openid-config url="https://login.microsoftonline.com/${var.oauth_tenant_id}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>${var.oauth_audience}</audience>
      </audiences>
      <issuers>
        <issuer>https://login.microsoftonline.com/${var.oauth_tenant_id}/v2.0</issuer>
        <issuer>https://sts.windows.net/${var.oauth_tenant_id}/</issuer>
      </issuers>
      <required-claims>
        <claim name="aud" match="any">
          <value>${var.oauth_audience}</value>
        </claim>
      </required-claims>
    </validate-jwt>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}
