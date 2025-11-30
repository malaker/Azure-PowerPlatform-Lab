# ===================================
# Enterprise Policy Configuration
# ===================================

variable "name" {
  description = "Name of the enterprise policy (Azure resource name)"
  type        = string
}

variable "display_name" {
  description = "Display name of the enterprise policy"
  type        = string
}

variable "location" {
  description = "Azure region for the enterprise policy (e.g., northeurope, westeurope)"
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID where the enterprise policy will be created"
  type        = string
}

variable "subnets" {
  description = "List of Azure subnets for Power Platform delegation across paired regions (minimum 2 required for business continuity)"
  type = list(object({
    id   = string
    name = string
  }))
  validation {
    condition     = length(var.subnets) >= 2
    error_message = "At least 2 subnets in paired Azure regions are required for Power Platform Enterprise Policy."
  }
}

variable "tags" {
  description = "Tags to apply to the enterprise policy"
  type        = map(string)
  default     = {}
}
