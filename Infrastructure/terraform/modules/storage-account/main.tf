# ===================================
# Storage Account
# ===================================

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = var.account_kind

  # Security settings
  https_traffic_only_enabled      = true
  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  shared_access_key_enabled       = var.shared_access_key_enabled

  # Network rules
  public_network_access_enabled = var.public_network_access_enabled

  dynamic "network_rules" {
    for_each = var.enable_network_rules ? [1] : []
    content {
      default_action             = var.default_network_action
      bypass                     = var.network_bypass
      ip_rules                   = var.allowed_ip_addresses
      virtual_network_subnet_ids = var.allowed_subnet_ids
    }
  }

  # Blob properties
  dynamic "blob_properties" {
    for_each = var.enable_blob_properties ? [1] : []
    content {
      # Versioning - this is a boolean attribute, not a block
      versioning_enabled = var.enable_versioning

      # Change feed - this is a boolean attribute, not a block
      change_feed_enabled = var.enable_change_feed

      # Soft delete for blobs
      dynamic "delete_retention_policy" {
        for_each = var.blob_soft_delete_retention_days > 0 ? [1] : []
        content {
          days = var.blob_soft_delete_retention_days
        }
      }

      # Soft delete for containers
      dynamic "container_delete_retention_policy" {
        for_each = var.container_soft_delete_retention_days > 0 ? [1] : []
        content {
          days = var.container_soft_delete_retention_days
        }
      }
    }
  }

  tags = var.tags
}

# ===================================
# Queue Properties (Separate Resource in v4+)
# ===================================

resource "azurerm_storage_account_queue_properties" "this" {
  count              = var.enable_queue_properties && var.enable_queue_logging ? 1 : 0
  storage_account_id = azurerm_storage_account.this.id

  # Logging
  logging {
    delete                = true
    read                  = true
    write                 = true
    version               = "1.0"
    retention_policy_days = var.queue_logging_retention_days
  }
}
