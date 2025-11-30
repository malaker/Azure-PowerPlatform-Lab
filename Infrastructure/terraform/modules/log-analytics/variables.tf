# ===================================
# Required Variables
# ===================================

variable "workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the workspace"
  type        = string
}

# ===================================
# Optional Variables
# ===================================

variable "sku" {
  description = "SKU for Log Analytics Workspace (PerGB2018, Free, etc.)"
  type        = string
  default     = "PerGB2018"

  validation {
    condition     = contains(["Free", "PerGB2018", "PerNode", "Premium", "Standalone", "Unlimited"], var.sku)
    error_message = "SKU must be one of: Free, PerGB2018, PerNode, Premium, Standalone, Unlimited."
  }
}

variable "retention_in_days" {
  description = "Retention period in days (30-730 for PerGB2018, 7 for Free)"
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 7 && var.retention_in_days <= 730
    error_message = "Retention must be between 7 and 730 days."
  }
}

variable "tags" {
  description = "Tags to apply to the workspace"
  type        = map(string)
  default     = {}
}
