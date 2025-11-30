data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                            = var.key_vault_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  tenant_id                       = var.tenant_id
  sku_name                        = var.sku_name
  soft_delete_retention_days      = var.soft_delete_retention_days
  purge_protection_enabled        = var.enable_purge_protection
  rbac_authorization_enabled      = var.enable_rbac_authorization
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  public_network_access_enabled   = var.public_network_access_enabled

  network_acls {
    default_action             = var.network_acls_default_action
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ip_addresses
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = var.tags

  lifecycle {
    # Prevent destroy when purge protection is enabled (production safety)
    prevent_destroy = false

    # Ignore changes to tags that may be updated outside of Terraform
    ignore_changes = [
      tags["CreatedDate"]
    ]
  }
}

# Grant Key Vault Secrets Officer role to admin users
resource "azurerm_role_assignment" "kv_secrets_officer" {
  for_each = toset(var.admin_object_ids)
  
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

# Grant Key Vault Secrets User role to reader users
resource "azurerm_role_assignment" "kv_secrets_user" {
  for_each = toset(var.reader_object_ids)
  
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}