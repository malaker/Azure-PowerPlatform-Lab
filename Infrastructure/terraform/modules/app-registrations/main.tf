data "azurerm_client_config" "current" {}

# Generate a UUID for the API scope
resource "random_uuid" "api_scope_id" {
  count = var.expose_api ? 1 : 0
}

# Generate UUIDs for app roles
resource "random_uuid" "app_role_id" {
  count = var.expose_app_roles ? length(var.app_roles) : 0
}

# Create App Registration
resource "azuread_application" "this" {
  display_name = var.display_name
  description  = var.description

  sign_in_audience = var.sign_in_audience

  # Optional: Web configuration
  dynamic "web" {
    for_each = length(var.redirect_uris) > 0 ? [1] : []
    content {
      redirect_uris = var.redirect_uris
    }
  }

  # Optional: API permissions
  dynamic "required_resource_access" {
    for_each = var.required_resource_access
    content {
      resource_app_id = required_resource_access.value.resource_app_id

      dynamic "resource_access" {
        for_each = required_resource_access.value.resource_access
        content {
          id   = resource_access.value.id
          type = resource_access.value.type
        }
      }
    }
  }

  # Expose API with oauth2 permission scope (for resource/audience apps)
  dynamic "api" {
    for_each = var.expose_api ? [1] : []
    content {
      oauth2_permission_scope {
        admin_consent_description  = var.api_scope_description
        admin_consent_display_name = var.api_scope_name
        enabled                    = true
        id                         = random_uuid.api_scope_id[0].result
        type                       = "Admin"
        value                      = var.api_scope_name
      }
    }
  }

  # Expose app roles for application permissions (client credentials flow)
  dynamic "app_role" {
    for_each = var.expose_app_roles ? var.app_roles : []
    content {
      allowed_member_types = ["Application"]
      description          = app_role.value.description
      display_name         = app_role.value.display_name
      enabled              = app_role.value.enabled
      id                   = random_uuid.app_role_id[index(var.app_roles, app_role.value)].result
      value                = app_role.value.value
    }
  }

  # Set identifier URI for exposed API using client_id format (required by tenant policy)
  # Note: identifier_uris is set after creation via lifecycle or separate resource
  # identifier_uris = var.expose_api ? ["api://${azuread_application.this.client_id}"] : []
}

# Update identifier URI after app creation (uses client_id to comply with tenant policy)
resource "azuread_application_identifier_uri" "this" {
  count          = var.expose_api ? 1 : 0
  application_id = azuread_application.this.id
  identifier_uri = "api://${azuread_application.this.client_id}"
}

# Create Service Principal
resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id

  app_role_assignment_required = var.app_role_assignment_required
}

# Create Client Secret
resource "azuread_application_password" "this" {
  application_id = azuread_application.this.id
  display_name   = "${var.display_name}-secret"
  
  end_date_relative = var.secret_expiration
}

# Store secret in Key Vault (if enabled)
resource "azurerm_key_vault_secret" "client_id" {
  count = var.store_secret_in_keyvault ? 1 : 0
  
  name         = "${var.display_name}-client-id"
  value        = azuread_application.this.client_id
  key_vault_id = var.key_vault_id
  
  tags = {
    application = var.display_name
    type        = "client-id"
  }
}

resource "azurerm_key_vault_secret" "client_secret" {
  count = var.store_secret_in_keyvault ? 1 : 0

  name         = "${var.display_name}-client-secret"
  value        = azuread_application_password.this.value
  key_vault_id = var.key_vault_id

  tags = {
    application = var.display_name
    type        = "client-secret"
  }
}

# ===================================
# Federated Identity Credentials
# ===================================

# Create federated identity credentials for workload identity federation
# Used for Power Platform Dataverse plugin authentication
resource "azuread_application_federated_identity_credential" "this" {
  for_each = { for cred in var.federated_credentials : cred.display_name => cred }

  application_id = azuread_application.this.id
  display_name   = each.value.display_name
  description    = each.value.description
  audiences      = each.value.audiences
  issuer         = each.value.issuer
  subject        = each.value.subject
}