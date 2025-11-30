output "application_id" {
  description = "Application (client) ID"
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Object ID of the application"
  value       = azuread_application.this.object_id
}

output "client_id" {
  description = "Client ID (same as application_id)"
  value       = azuread_application.this.client_id
}

output "service_principal_id" {
  description = "Service Principal Object ID"
  value       = azuread_service_principal.this.object_id
}

output "client_secret" {
  description = "Client secret value (sensitive)"
  value       = azuread_application_password.this.value
  sensitive   = true
}

output "secret_key_name" {
  description = "Name of the client secret in Key Vault"
  value       = var.store_secret_in_keyvault ? azurerm_key_vault_secret.client_secret[0].name : ""
}

output "client_id_name" {
  description = "Name of the client ID secret in Key Vault"
  value       = var.store_secret_in_keyvault ? azurerm_key_vault_secret.client_id[0].name : ""
}

output "application_object_id" {
  description = "Application Object ID (used for federated credentials)"
  value       = azuread_application.this.id
}

output "api_scope_id" {
  description = "ID of the exposed API scope (for granting permissions)"
  value       = var.expose_api ? random_uuid.api_scope_id[0].result : null
}

output "api_scope_name" {
  description = "Name/value of the exposed API scope (e.g., 'access_as_user')"
  value       = var.expose_api ? var.api_scope_name : null
}

output "identifier_uri" {
  description = "Identifier URI of the exposed API"
  value       = var.expose_api ? azuread_application_identifier_uri.this[0].identifier_uri : null
}

output "app_role_ids" {
  description = "Map of app role values to their IDs (for granting application permissions)"
  value = var.expose_app_roles ? {
    for idx, role in var.app_roles : role.value => random_uuid.app_role_id[idx].result
  } : {}
}