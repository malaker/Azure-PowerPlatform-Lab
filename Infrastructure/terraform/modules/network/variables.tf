# ===================================
# Required Variables
# ===================================

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the resources"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}

# ===================================
# Subnet Variables
# ===================================

variable "subnet_powerplatform_name" {
  description = "Name of the Power Platform subnet"
  type        = string
}

variable "subnet_powerplatform_address_prefixes" {
  description = "Address prefixes for the Power Platform subnet"
  type        = list(string)
}

variable "subnet_logicapps_name" {
  description = "Name of the Logic Apps subnet"
  type        = string
}

variable "subnet_logicapps_address_prefixes" {
  description = "Address prefixes for the Logic Apps subnet"
  type        = list(string)
}

variable "subnet_apim_name" {
  description = "Name of the API Management subnet"
  type        = string
}

variable "subnet_apim_address_prefixes" {
  description = "Address prefixes for the API Management subnet"
  type        = list(string)
}

variable "subnet_fn_name" {
  description = "Name of the Functions subnet"
  type        = string
}

variable "subnet_fn_address_prefixes" {
  description = "Address prefixes for the Functions subnet"
  type        = list(string)
}

variable "subnet_storage_name" {
  description = "Name of the Storage subnet"
  type        = string
}

variable "subnet_storage_address_prefixes" {
  description = "Address prefixes for the Storage subnet"
  type        = list(string)
}

variable "subnet_nat_name" {
  description = "Name of the NAT Gateway subnet"
  type        = string
}

variable "subnet_nat_address_prefixes" {
  description = "Address prefixes for the NAT Gateway subnet"
  type        = list(string)
}

# ===================================
# NAT Gateway Variables
# ===================================

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway with static public IP for outbound traffic"
  type        = bool
  default     = true
}

variable "nat_gateway_idle_timeout" {
  description = "Idle timeout in minutes for NAT Gateway"
  type        = number
  default     = 4
}

variable "nat_gateway_zones" {
  description = "Availability zone for NAT Gateway - only ONE zone supported (e.g., [\"1\"])"
  type        = list(string)
  default     = null

  validation {
    condition     = var.nat_gateway_zones == null || length(var.nat_gateway_zones) <= 1
    error_message = "NAT Gateway only supports a single availability zone. Provide a list with one zone (e.g., [\"1\"]) or null."
  }
}

variable "enable_nat_subnet_association" {
  description = "Enable NAT Gateway association with NAT subnet"
  type        = bool
  default     = false
}

# ===================================
# Optional Variables
# ===================================

variable "enable_powerplatform_delegation" {
  description = "Enable Power Platform enterprise policy delegation on the Power Platform subnet"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
