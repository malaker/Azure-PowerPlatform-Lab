# ===================================
# Local Variables
# ===================================

locals {
  # Apply random suffix to resource names if provided
  # This ensures globally unique names when code is shared or open-sourced
  function_app_name_unique = var.random_suffix != "" ? "${var.function_app_name}-${var.random_suffix}" : var.function_app_name
  app_insights_name_unique = var.random_suffix != "" ? "${var.app_insights_name}-${var.random_suffix}" : var.app_insights_name
}

# ===================================
# Application Insights
# ===================================

# Application Insights for monitoring and diagnostics
resource "azurerm_application_insights" "function" {
  name                = local.app_insights_name_unique
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id

  tags = var.tags
}

# ===================================
# App Service Plan (Flex Consumption)
# ===================================

resource "azurerm_service_plan" "function" {
  name                = "${var.function_app_name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = var.tags
}

# ===================================
# Storage Container for Deployment
# ===================================

resource "azurerm_storage_container" "deploymentpackage" {
  name                  = "deploymentpackage"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

# ===================================
# Function App (Flex Consumption)
# ===================================

# Flex Consumption Function App (Linux)
resource "azurerm_function_app_flex_consumption" "function" {
  name                = local.function_app_name_unique
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.function.id

  # Storage configuration - Flex Consumption uses blob container storage
  storage_container_type      = "blobContainer"
  storage_authentication_type = "SystemAssignedIdentity"
  storage_container_endpoint  = "${var.storage_blob_endpoint}${azurerm_storage_container.deploymentpackage.name}"

  # Runtime configuration
  runtime_name    = var.runtime # Use full runtime name (e.g., "dotnet-isolated", "node", "python")
  runtime_version = var.runtime == "dotnet-isolated" ? "8.0" : "20"

  # Scaling configuration
  maximum_instance_count = var.max_instance_count
  instance_memory_in_mb  = var.instance_memory_mb

  # VNet integration for outbound traffic
  virtual_network_subnet_id = var.subnet_id

  # Enable HTTPS only
  https_only = true

  # Identity for managed service identity and storage access
  identity {
    type = "SystemAssigned"
  }

  # Site configuration
  site_config {
    # Application Insights
    application_insights_connection_string = azurerm_application_insights.function.connection_string

    # CORS configuration (if needed)
    dynamic "cors" {
      for_each = length(var.cors_allowed_origins) > 0 ? [1] : []
      content {
        allowed_origins     = var.cors_allowed_origins
        support_credentials = var.cors_support_credentials
      }
    }

    # IP restrictions for inbound traffic (allow only from APIM subnet)
    dynamic "ip_restriction" {
      for_each = var.allowed_subnet_ids
      content {
        name                      = "Allow-${ip_restriction.key}"
        virtual_network_subnet_id = ip_restriction.value
        action                    = "Allow"
        priority                  = 100 + ip_restriction.key
      }
    }

    # Deny all other traffic if restrictions are defined
    dynamic "ip_restriction" {
      for_each = length(var.allowed_subnet_ids) > 0 ? [1] : []
      content {
        name       = "Deny-All"
        action     = "Deny"
        priority   = 2147483647
        ip_address = "0.0.0.0/0"
      }
    }
  }

  # Application settings
  app_settings = merge(
    {
      # Note: FUNCTIONS_WORKER_RUNTIME is not allowed for Flex Consumption (set via runtime_name instead)
      "FUNCTIONS_EXTENSION_VERSION"           = "~4"
      "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.function.instrumentation_key
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.function.connection_string
      "AzureWebJobsStorage"                   = "" # Required workaround for Flex Consumption
      "AzureWebJobsStorage__accountName"      = var.storage_account_name
    },
    var.app_settings
  )

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags that might be added by Azure
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-conn-string"],
    ]
  }
}
