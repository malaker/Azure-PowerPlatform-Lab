# ===================================
# Logic App API Connections Module
# ===================================
# Creates API connections for Logic Apps using credentials from Key Vault
# Supports Common Data Service (Dataverse) and custom API connections

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

# ===================================
# Common Data Service Connection
# ===================================

# Read the client secret from Key Vault
# API Connections cannot use Key Vault references directly - they need the actual secret value
data "azurerm_key_vault_secret" "dataverse_client_secret" {
  count = var.create_dataverse_connection ? 1 : 0

  name         = var.dataverse_client_secret_name
  key_vault_id = var.key_vault_id
}

# Pattern 1: Service Principal Authentication with Client Secret from Key Vault
# Using azapi_resource to create V2 connection with access policy support
resource "azapi_resource" "commondataservice" {
  count = var.create_dataverse_connection ? 1 : 0

  name      = var.dataverse_connection_name
  type      = "Microsoft.Web/connections@2016-06-01"
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location

  # Export the connectionRuntimeUrl from the API connection properties
  # This is needed for Logic App environment variables
  response_export_values = ["properties.connectionRuntimeUrl"]

  body = jsonencode({
    kind = "V2"
    properties = {
      displayName = var.dataverse_connection_display_name
      api = {
        id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Web/locations/${var.location}/managedApis/commondataservice"
      }
      parameterValueSet = {
        name = "ServicePrincipalOauth"
        values = {
          "token:TenantId" = {
            value = var.tenant_id
          }
          "token:clientId" = {
            value = var.dataverse_client_id
          }
          "token:clientSecret" = {
            value = data.azurerm_key_vault_secret.dataverse_client_secret[0].value
          }
          "token:grantType" = {
            value = "client_credentials"
          }
          "token:resourceUri" = {
            value = var.dataverse_environment_url
          }
        }
      }
    }
  })

  tags = var.tags

  # Disable schema validation to allow V2 connection with parameterValueSet
  schema_validation_enabled = false

  lifecycle {
    ignore_changes = [
      # Ignore changes to the client secret to prevent Terraform from showing drift
      body
    ]
  }
}

# Pattern 2: OAuth 2.0 Delegated Permissions (User Impersonation)
# This requires interactive login and cannot use Key Vault secrets directly
# Instead, you'd use Managed Identity or Service Principal with delegated permissions

# ===================================
# Azure Key Vault Connection
# ===================================

# Key Vault API Connection using Managed Identity
resource "azurerm_api_connection" "keyvault" {
  count = var.create_keyvault_connection ? 1 : 0

  name                = var.keyvault_connection_name
  resource_group_name = var.resource_group_name
  managed_api_id      = "${data.azurerm_subscription.current.id}/providers/Microsoft.Web/locations/${var.location}/managedApis/keyvault"
  display_name        = var.keyvault_connection_display_name

  # Using Managed Identity for Key Vault access
  parameter_values = {
    "vaultName" = var.key_vault_name
  }

  tags = var.tags
}

# ===================================
# Custom HTTP Connection (Generic API)
# ===================================

# Pattern 3: Custom API with API Key from Key Vault
resource "azurerm_api_connection" "custom_api" {
  count = var.create_custom_api_connection ? 1 : 0

  name                = var.custom_api_connection_name
  resource_group_name = var.resource_group_name
  managed_api_id      = "${data.azurerm_subscription.current.id}/providers/Microsoft.Web/locations/${var.location}/managedApis/webcontents"
  display_name        = var.custom_api_connection_display_name

  parameter_values = {
    "api_key" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/${var.custom_api_key_secret_name}/)"
  }

  tags = var.tags
}

# ===================================
# Access Policy for Logic App Managed Identity
# ===================================

# Grant Logic App Managed Identity access to read secrets from Key Vault
resource "azurerm_role_assignment" "logic_app_keyvault_secrets_user" {
  count = var.logic_app_principal_id != null && var.grant_keyvault_access ? 1 : 0

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.logic_app_principal_id
}

# ===================================
# Access Policy for API Connections
# ===================================

# Grant Logic App Managed Identity permission to use the Dataverse API Connection
# This is required for the connection to show as "Connected" in the portal
# Without this, the connection will show "Access Policies are missing"
resource "azurerm_role_assignment" "logic_app_dataverse_connection_user" {
  count = var.create_dataverse_connection && var.logic_app_principal_id != null ? 1 : 0

  scope                = azapi_resource.commondataservice[0].id
  role_definition_name = "Contributor"
  principal_id         = var.logic_app_principal_id
}

# Grant Logic App Managed Identity permission to use the Key Vault API Connection
resource "azurerm_role_assignment" "logic_app_keyvault_connection_user" {
  count = var.create_keyvault_connection && var.logic_app_principal_id != null ? 1 : 0

  scope                = azurerm_api_connection.keyvault[0].id
  role_definition_name = "Contributor"
  principal_id         = var.logic_app_principal_id
}

# Grant Logic App Managed Identity permission to use the Custom API Connection
resource "azurerm_role_assignment" "logic_app_custom_api_connection_user" {
  count = var.create_custom_api_connection && var.logic_app_principal_id != null ? 1 : 0

  scope                = azurerm_api_connection.custom_api[0].id
  role_definition_name = "Contributor"
  principal_id         = var.logic_app_principal_id
}

# ===================================
# Data Sources
# ===================================

data "azurerm_subscription" "current" {}
