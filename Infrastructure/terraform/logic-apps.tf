# ===================================
# Logic App Standard Deployment (Hybrid Pattern)
# ===================================
# This file demonstrates the RECOMMENDED hybrid pattern for Logic App Standard deployment:
#
# TERRAFORM CREATES:
# - App Service Plan (compute infrastructure)
# - Storage Account (runtime storage, initially without network restrictions)
# - Logic App Standard resources (with app settings, VNet integration, connections)
# - VNet configuration
# - API Connections
# - RBAC permissions
#
# WORKFLOWS DEPLOYED SEPARATELY (Azure CLI / VS Code / CI/CD):
# - Workflow definitions (workflow.json files)
# - Updated via ZIP deployment or VS Code extension
#
# This approach ensures:
# - Logic Apps created by Terraform with proper configuration
# - Workflows managed independently (no Terraform drift)
# - Full VS Code integration for workflow development
# - Network security applied after initial setup

# ===================================
# Shared Resources
# ===================================

# Shared Storage Account for all Logic Apps
module "storage_account_logicapps_shared" {
  count  = var.enable_logic_apps ? 1 : 0
  source = "./modules/storage-account"

  storage_account_name     = "${local.storage_account_name_prefix}logic${local.region_short}${local.random_suffix}"
  resource_group_name      = module.resource_groups["logicapps"].name
  location                 = module.resource_groups["logicapps"].location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  public_network_access_enabled   = true

  # Network rules enabled for security - Logic Apps subnet has service endpoints
  enable_network_rules   = true
  default_network_action = "Deny"
  network_bypass         = ["AzureServices", "Logging", "Metrics"]

  allowed_subnet_ids = concat(
    [module.network.subnet_logicapps_id],
    [module.network.subnet_powerplatform_id],
    var.enable_powerplatform_subnet_delegation ? [azurerm_subnet.northeurope_powerplatform[0].id] : []
  )

  enable_blob_properties  = true
  enable_queue_properties = true

  blob_soft_delete_retention_days      = var.environment == "prod" ? 30 : 7
  container_soft_delete_retention_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.common_tags,
    {
      Component = "Logic Apps"
      Purpose   = "Shared storage for Logic App Standard instances"
    }
  )

  depends_on = [module.resource_groups, module.network]
}

# Shared App Service Plan for all Logic Apps
resource "azurerm_service_plan" "logicapps_shared" {
  count = var.enable_logic_apps ? 1 : 0
  name                = "${var.environment}-${var.project_name}-logicapp-plan-${local.region_short}"
  resource_group_name = module.resource_groups["logicapps"].name
  location            = module.resource_groups["logicapps"].location
  os_type             = "Windows"
  sku_name            = "WS1" # Can be upgraded to WS2 or WS3 for more resources

  tags = merge(
    local.common_tags,
    {
      Component = "Logic Apps"
      Purpose   = "Shared App Service Plan for Logic App Standard"
    }
  )

  depends_on = [module.resource_groups]
}

# ===================================
# API Connections (Shared)
# ===================================

module "logic_app_connections" {
  count  = var.enable_logic_apps ? 1 : 0
  source = "./modules/logic-app-connections"

  resource_group_name = module.resource_groups["logicapps"].name
  location            = module.resource_groups["logicapps"].location

  key_vault_id   = module.key_vault.key_vault_id
  key_vault_uri  = module.key_vault.key_vault_uri
  key_vault_name = module.key_vault.key_vault_name
  tenant_id      = data.azurerm_client_config.current.tenant_id

  create_dataverse_connection  = true
  dataverse_connection_name    = "commondataservice-${var.environment}"
  dataverse_client_id          = module.app_registrations["logic-app-dataverse-svc"].client_id
  dataverse_client_secret_name = module.app_registrations["logic-app-dataverse-svc"].secret_key_name
  dataverse_environment_url    = length(module.powerplatform) > 0 ? module.powerplatform[keys(module.powerplatform)[0]].environment_url : ""

  tags = merge(
    local.common_tags,
    {
      Component = "Logic Apps"
      Purpose   = "API Connections for Dataverse integration"
    }
  )

  depends_on = [
    module.key_vault,
    module.app_registrations,
    module.resource_groups
  ]
}

# ===================================
# Logic App Configuration
# ===================================

locals {
  # Common IP restrictions for all Logic Apps
  # IMPORTANT: Dataverse triggers do NOT use the delegated subnet for inbound traffic
  # Instead, they use the PowerPlatformInfra service tag to communicate with Logic Apps
  # This is why we need both subnet-based rules AND service tag rules
  common_ip_restrictions = concat(
    [
      # Allow inbound traffic from Power Platform subnet (West Europe)
      # Used for: Custom connectors, HTTP actions from Power Platform
      {
        name                      = "Allow-PowerPlatform-WestEurope"
        virtual_network_subnet_id = module.network.subnet_powerplatform_id
        priority                  = 100
        action                    = "Allow"
      },
      # Allow inbound traffic from Functions subnet
      # Used for: Function App calling Logic Apps via HTTP
      {
        name                      = "Allow-Functions-WestEurope"
        virtual_network_subnet_id = module.network.subnet_fn_id
        priority                  = 110
        action                    = "Allow"
      },
      # Allow inbound traffic from PowerPlatformInfra service tag
      # CRITICAL for Dataverse triggers: Dataverse does NOT route through delegated subnets
      # Instead, it uses Microsoft-managed infrastructure (PowerPlatformInfra service tag)
      # This rule is REQUIRED for Dataverse triggers to work with Logic Apps
      # Reference: https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-overview
      {
        name             = "Allow-PowerPlatformInfra-Tag"
        service_tag      = "PowerPlatformInfra"
        priority         = 130
        action           = "Allow"
      }
    ],
    var.enable_powerplatform_subnet_delegation ? [
      # Allow inbound traffic from Power Platform subnet (North Europe - paired region)
      # Used for: Enterprise policy with dual-region VNet setup
      {
        name                      = "Allow-PowerPlatform-NorthEurope"
        virtual_network_subnet_id = azurerm_subnet.northeurope_powerplatform[0].id
        priority                  = 120
        action                    = "Allow"
      }
    ] : []
  )

  # Common app settings for all Logic Apps
  # Only populated when Logic Apps are enabled
  common_app_settings = var.enable_logic_apps ? {
    # Dataverse configuration
    "Dataverse_Url" = length(module.powerplatform) > 0 ? module.powerplatform[keys(module.powerplatform)[0]].environment_url : ""

    # APIM Configuration
    "APIM_BaseUri" = var.enable_api_management ? "${module.api_management[0].gateway_url}" : ""
    "APIM_Scope"   = "api://${module.app_registrations["az-function-backend"].client_id}/.default"

    # Connection reference settings (used by connections.json)
    "WORKFLOWS_SUBSCRIPTION_ID"                  = data.azurerm_client_config.current.subscription_id
    "WORKFLOWS_LOCATION_NAME"                    = module.resource_groups["logicapps"].location
    "WORKFLOWS_RESOURCE_GROUP_NAME"              = module.resource_groups["logicapps"].name
    "WORKFLOWS_ENVIRONMENT_NAME"                 = var.environment
    "commondataservice_connectionRuntimeUrl"     = module.logic_app_connections[0].dataverse_connection_runtime_url
  } : {}

  # Define multiple Logic App configurations
  logic_apps = {
    dataverse-integration = {
      name        = "${var.environment}-${var.project_name}-logicapp-${local.region_short}"
      description = "Logic app that demonstratrates integration with Dataverse and other Azure Services"
      app_settings = merge(
        local.common_app_settings,
        {
          "WorkflowType" = "LogicAppLab"
        }
      )
    }
  }
}

# ===================================
# Logic App Standard Resources (using module)
# ===================================
# Terraform creates the Logic App resources with full configuration
# Workflows are deployed separately via VS Code or Azure CLI

module "logic_apps" {
  source = "./modules/logic-app-standard"

  for_each = var.enable_logic_apps ? local.logic_apps : {}

  # Basic configuration
  logic_app_name      = each.value.name
  resource_group_name = module.resource_groups["logicapps"].name
  location            = module.resource_groups["logicapps"].location

  # Shared random suffix for consistent naming across all resources
  random_suffix = local.random_suffix

  # Use shared App Service Plan (all workflows run on same plan)
  create_app_service_plan = false
  app_service_plan_id     = azurerm_service_plan.logicapps_shared[0].id

  # Use shared storage account
  storage_account_name       = module.storage_account_logicapps_shared[0].storage_account_name
  storage_account_access_key = module.storage_account_logicapps_shared[0].primary_access_key
  storage_account_id         = module.storage_account_logicapps_shared[0].storage_account_id

  # VNet integration
  virtual_network_subnet_id  = module.network.subnet_logicapps_id
  vnet_route_all_enabled     = true
  enable_vnet_content_access = true

  # Identity Configuration
  # Use user-assigned identity for better reliability with network-restricted storage
  # The identity is created with RBAC roles BEFORE Logic App, ensuring file share can be created
  use_user_assigned_identity = true

  # Security
  min_tls_version = "1.2"
  always_on       = true
  ip_restrictions = local.common_ip_restrictions

  # App settings (workflow-specific + common)
  app_settings = merge(
    each.value.app_settings,
    var.additional_logic_app_settings
  )

  # RBAC
  grant_key_vault_permissions = true
  key_vault_id                = module.key_vault.key_vault_id
  grant_storage_permissions   = true

  tags = merge(
    local.common_tags,
    {
      Component    = "Logic Apps"
      Purpose      = each.value.description
      WorkflowType = each.key
    }
  )

  depends_on = [
    azurerm_service_plan.logicapps_shared,
    module.storage_account_logicapps_shared,
    module.logic_app_connections,
    module.network,
    module.key_vault
  ]
}

# ===================================
# API Connection Access Policies
# ===================================
# Grant each Logic App's managed identity permission to use the API connections
# This must be done AFTER Logic Apps are created to avoid circular dependency
#
# IMPORTANT: We use Microsoft.Web/connections/accessPolicies instead of RBAC
# This makes the Logic App show up in the "Access policies" blade in the portal

resource "azapi_resource" "logic_apps_dataverse_connection_access_policy" {
  for_each = module.logic_apps

  type      = "Microsoft.Web/connections/accessPolicies@2016-06-01"
  name      = each.value.logic_app_principal_id
  parent_id = module.logic_app_connections[0].dataverse_connection_id

  # Disable schema validation as accessPolicies is not in the azapi provider schema
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      principal = {
        type = "ActiveDirectory"
        identity = {
          tenantId = data.azurerm_client_config.current.tenant_id
          objectId = each.value.logic_app_principal_id
        }
      }
    }
  })

  depends_on = [
    module.logic_apps,
    module.logic_app_connections
  ]
}

# ===================================
# Outputs
# ===================================

output "logic_apps" {
  description = "Logic App Standard instances"
  value = {
    for key, app in module.logic_apps : key => {
      id               = app.logic_app_id
      name             = app.logic_app_name
      principal_id     = app.logic_app_principal_id
      default_hostname = app.logic_app_default_hostname
    }
  }
}

output "logic_app_storage_account_name" {
  description = "Shared storage account name for Logic Apps"
  value       = var.enable_logic_apps ? module.storage_account_logicapps_shared[0].storage_account_name : null
}

output "logic_app_service_plan_id" {
  description = "Shared App Service Plan ID for Logic Apps"
  value       = var.enable_logic_apps ? azurerm_service_plan.logicapps_shared[0].id : null
}

output "logic_app_workflow_deployment_info" {
  description = "Information for deploying workflows to Logic Apps"
  value = {
    for key, app in module.logic_apps : key => {
      # VS Code deployment info
      logic_app_name      = app.logic_app_name
      resource_group_name = app.resource_group_name

      # CLI deployment command
      cli_deploy_command = "az logicapp deployment source config-zip --name ${app.logic_app_name} --resource-group ${app.resource_group_name} --src ./workflows.zip"
    }
  }
}
