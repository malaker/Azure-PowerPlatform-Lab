# ===================================
# Required Variables
# ===================================

variable "storage_account_name" {
  description = "Name of the Storage Account"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be between 3 and 24 characters, lowercase letters and numbers only."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the storage account"
  type        = string
}

# ===================================
# Optional Variables
# ===================================

variable "account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "Account tier must be either 'Standard' or 'Premium'."
  }
}

variable "account_replication_type" {
  description = "Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "Replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "account_kind" {
  description = "Storage account kind (BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2)"
  type        = string
  default     = "StorageV2"

  validation {
    condition     = contains(["BlobStorage", "BlockBlobStorage", "FileStorage", "Storage", "StorageV2"], var.account_kind)
    error_message = "Account kind must be one of: BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2."
  }
}

variable "min_tls_version" {
  description = "Minimum TLS version (TLS1_0, TLS1_1, TLS1_2)"
  type        = string
  default     = "TLS1_2"

  validation {
    condition     = contains(["TLS1_0", "TLS1_1", "TLS1_2"], var.min_tls_version)
    error_message = "Minimum TLS version must be one of: TLS1_0, TLS1_1, TLS1_2."
  }
}

variable "allow_nested_items_to_be_public" {
  description = "Allow blob containers to be made public"
  type        = bool
  default     = false
}

variable "shared_access_key_enabled" {
  description = "Enable storage account access keys"
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = true
}

# ===================================
# Network Rules
# ===================================

variable "enable_network_rules" {
  description = "Enable network rules for the storage account"
  type        = bool
  default     = false
}

variable "default_network_action" {
  description = "Default action for network rules (Allow or Deny)"
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.default_network_action)
    error_message = "Default network action must be either 'Allow' or 'Deny'."
  }
}

variable "network_bypass" {
  description = "Traffic types to bypass network rules"
  type        = list(string)
  default     = ["AzureServices"]

  validation {
    condition = alltrue([
      for bypass in var.network_bypass : contains(["AzureServices", "Logging", "Metrics", "None"], bypass)
    ])
    error_message = "Network bypass must contain only: AzureServices, Logging, Metrics, None."
  }
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses allowed to access the storage account"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access the storage account"
  type        = list(string)
  default     = []
}

# ===================================
# Blob Properties
# ===================================

variable "enable_blob_properties" {
  description = "Enable blob-specific properties"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Enable blob versioning"
  type        = bool
  default     = false
}

variable "enable_change_feed" {
  description = "Enable blob change feed"
  type        = bool
  default     = false
}

variable "blob_soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted blobs (0 to disable)"
  type        = number
  default     = 7

  validation {
    condition     = var.blob_soft_delete_retention_days >= 0 && var.blob_soft_delete_retention_days <= 365
    error_message = "Blob soft delete retention must be between 0 and 365 days."
  }
}

variable "container_soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted containers (0 to disable)"
  type        = number
  default     = 7

  validation {
    condition     = var.container_soft_delete_retention_days >= 0 && var.container_soft_delete_retention_days <= 365
    error_message = "Container soft delete retention must be between 0 and 365 days."
  }
}

# ===================================
# Queue Properties
# ===================================

variable "enable_queue_properties" {
  description = "Enable queue-specific properties"
  type        = bool
  default     = true
}

variable "enable_queue_logging" {
  description = "Enable queue logging"
  type        = bool
  default     = false
}

variable "queue_logging_retention_days" {
  description = "Number of days to retain queue logs"
  type        = number
  default     = 7

  validation {
    condition     = var.queue_logging_retention_days >= 1 && var.queue_logging_retention_days <= 365
    error_message = "Queue logging retention must be between 1 and 365 days."
  }
}

# ===================================
# Tags
# ===================================

variable "tags" {
  description = "Tags to apply to the storage account"
  type        = map(string)
  default     = {}
}
