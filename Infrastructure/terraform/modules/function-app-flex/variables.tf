# ===================================
# Required Variables
# ===================================

variable "function_app_name" {
  description = "Name of the Function App"
  type        = string
}

variable "random_suffix" {
  description = "Random suffix for globally unique resource names (optional)"
  type        = string
  default     = ""
}

variable "storage_account_id" {
  description = "ID of the external Storage Account for Function App"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the external Storage Account for Function App"
  type        = string
}

variable "storage_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  type        = string
}

variable "app_insights_name" {
  description = "Name of the Application Insights instance"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for VNet integration (outbound traffic)"
  type        = string
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access the Function App (inbound traffic restrictions)"
  type        = list(string)
  default     = []
}

# ===================================
# Optional Variables
# ===================================

variable "runtime" {
  description = "Function App runtime (dotnet-isolated, node, python, java, powershell)"
  type        = string
  default     = "dotnet-isolated"

  validation {
    condition     = contains(["dotnet-isolated", "node", "python", "java", "powershell"], var.runtime)
    error_message = "Runtime must be one of: dotnet-isolated, node, python, java, powershell."
  }
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace for Application Insights"
  type        = string
  default     = null
}

variable "app_settings" {
  description = "Additional application settings for the Function App"
  type        = map(string)
  default     = {}
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = []
}

variable "cors_support_credentials" {
  description = "Enable CORS support for credentials"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ===================================
# Flex Consumption Configuration
# ===================================

variable "max_instance_count" {
  description = "Maximum number of instances for Flex Consumption scaling (minimum 40)"
  type        = number
  default     = 40

  validation {
    condition     = var.max_instance_count >= 40 && var.max_instance_count <= 1000
    error_message = "Maximum instance count must be between 40 and 1000."
  }
}

variable "instance_memory_mb" {
  description = "Memory allocated per instance in MB (512, 2048, 4096)"
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 2048, 4096], var.instance_memory_mb)
    error_message = "Instance memory must be 512, 2048, or 4096 MB."
  }
}

variable "always_ready_instances" {
  description = "Number of always-ready instances (0-10)"
  type        = number
  default     = 0

  validation {
    condition     = var.always_ready_instances >= 0 && var.always_ready_instances <= 10
    error_message = "Always ready instances must be between 0 and 10."
  }
}

variable "per_instance_concurrency" {
  description = "Maximum concurrent executions per instance"
  type        = number
  default     = 1

  validation {
    condition     = var.per_instance_concurrency >= 1
    error_message = "Per instance concurrency must be at least 1."
  }
}

variable "trigger_type" {
  description = "Trigger type for the function app (http, queue, etc.)"
  type        = string
  default     = "http"
}

variable "max_batch_size" {
  description = "Maximum batch size for trigger processing"
  type        = number
  default     = 1

  validation {
    condition     = var.max_batch_size >= 1
    error_message = "Max batch size must be at least 1."
  }
}
