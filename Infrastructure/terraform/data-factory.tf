# ===================================
# Azure Data Factory Deployment
# ===================================
# This file deploys Azure Data Factory with managed VNet for secure connectivity.
#
# Network Architecture:
# - Managed VNet with Azure Integration Runtime
# - Managed Private Endpoints to Storage and Key Vault
# - Outbound traffic routes through NAT Gateway (whitelistable IP for Power Platform)
#
# Key Features:
# - ETL/ELT pipelines between Power Platform and Azure services
# - Secure connectivity via managed private endpoints
# - Service principal authentication to Dataverse
# - Integration with APIM for API-based data flows

# ===================================
# Storage Account for Data Factory
# ===================================
# Dedicated storage account for Data Factory staging and intermediate data

module "storage_account_datafactory" {
  count  = var.enable_data_factory ? 1 : 0
  source = "./modules/storage-account"

  # Storage account naming: {env}{project}adf{region}{random}
  # Example: devpplab01adfweua1b2 (21 chars)
  storage_account_name     = "${local.storage_account_name_prefix}adf${local.region_short}${local.random_suffix}"
  resource_group_name      = module.resource_groups["datafactory"].name
  location                 = module.resource_groups["datafactory"].location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  public_network_access_enabled   = true

  # Network rules - allow access from relevant subnets
  enable_network_rules   = true
  default_network_action = "Deny"
  network_bypass         = ["AzureServices", "Logging", "Metrics"]

  # Allow access from Power Platform and NAT subnets
  # Data Factory uses managed private endpoints, so it doesn't need subnet access
  # But we allow Power Platform for potential direct access scenarios
  allowed_subnet_ids = concat(
    [module.network.subnet_powerplatform_id],
    var.enable_powerplatform_subnet_delegation ? [azurerm_subnet.northeurope_powerplatform[0].id] : []
  )

  # Enable blob properties for Data Factory staging
  enable_blob_properties = true

  # Soft delete retention (environment-specific)
  blob_soft_delete_retention_days      = var.environment == "prod" ? 30 : 7
  container_soft_delete_retention_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.common_tags,
    {
      Component = "Data Factory"
      Purpose   = "Staging and intermediate data storage for ETL pipelines"
    }
  )

  depends_on = [module.resource_groups, module.network]
}

# ===================================
# Azure Data Factory
# ===================================

module "data_factory" {
  count  = var.enable_data_factory ? 1 : 0
  source = "./modules/data-factory"

  # Data Factory naming: {env}-{project}-adf-{region}-{random}
  # Example: dev-pplab01-adf-weu-a1b2
  data_factory_name   = "${var.environment}-${var.project_name}-adf-${local.region_short}"
  random_suffix       = local.random_suffix
  resource_group_name = module.resource_groups["datafactory"].name
  location            = module.resource_groups["datafactory"].location

  # ===================================
  # Managed VNet Configuration
  # ===================================
  # CRITICAL: Managed VNet enables:
  # 1. Network isolation for data processing
  # 2. Managed private endpoints to Azure services
  # 3. Outbound traffic through NAT Gateway (whitelistable IP for Power Platform)
  enable_managed_vnet = true

  # Note: Azure Data Factory does not support public_network_access_enabled property
  # Use Azure Firewall or Private Link for access control
  # Managed VNet provides network isolation for integration runtime

  # ===================================
  # Integration Runtime Configuration
  # ===================================
  # Azure Integration Runtime with managed VNet
  # - General compute type (8 cores) suitable for most workloads
  # - 5-minute TTL to avoid cold starts while controlling costs
  integration_runtime_compute_type = "General"
  integration_runtime_core_count   = var.environment == "prod" ? 16 : 8
  integration_runtime_ttl_minutes  = 5

  # ===================================
  # Azure Services Integration
  # ===================================

  # Storage Account (for staging and intermediate data)
  storage_account_id   = module.storage_account_datafactory[0].storage_account_id
  storage_account_name = module.storage_account_datafactory[0].storage_account_name

  # Key Vault (for secrets management)
  key_vault_id = module.key_vault.key_vault_id

  # ===================================
  # Power Platform Integration
  # ===================================
  # Enable Dataverse linked service for Power Platform connectivity
  # IMPORTANT: Outbound traffic goes through NAT Gateway
  # Add NAT Gateway public IP to Power Platform IP firewall allowlist
  enable_dataverse_linked_service = length(module.powerplatform) > 0

  # Dataverse connection details
  # Uses service principal authentication via Key Vault
  dataverse_environment_url = length(module.powerplatform) > 0 ? module.powerplatform[keys(module.powerplatform)[0]].environment_url : ""

  # Extract organization name from environment URL
  # Example: https://org.crm4.dynamics.com -> org
  dataverse_organization_name = length(module.powerplatform) > 0 ? split(".", split("//", module.powerplatform[keys(module.powerplatform)[0]].environment_url)[1])[0] : ""

  # Service principal for Dataverse authentication
  # Use dedicated Data Factory app registration for better security and auditability
  dataverse_service_principal_id          = module.app_registrations["data-factory-dataverse-svc"].client_id
  dataverse_service_principal_secret_name = module.app_registrations["data-factory-dataverse-svc"].secret_key_name
  tenant_id                               = data.azurerm_client_config.current.tenant_id

  # ===================================
  # API Management Integration
  # ===================================
  # Enable APIM linked service for API-based data flows
  enable_apim_linked_service = var.enable_api_management
  apim_gateway_url           = var.enable_api_management ? module.api_management[0].gateway_url : ""
  apim_authentication_type   = "Anonymous" # Use APIM subscription key or OAuth for production

  # ===================================
  # Global Parameters
  # ===================================
  # Global parameters accessible across all pipelines
  # Only include parameters with non-empty values
  global_parameters = concat(
    [
      {
        name  = "Environment"
        type  = "String"
        value = var.environment
      }
    ],
    var.enable_nat_gateway ? [
      {
        name  = "NatGatewayPublicIp"
        type  = "String"
        value = module.network.nat_public_ip_address
      }
    ] : [],
    length(module.powerplatform) > 0 ? [
      {
        name  = "DataverseUrl"
        type  = "String"
        value = module.powerplatform[keys(module.powerplatform)[0]].environment_url
      }
    ] : [],
    var.enable_api_management ? [
      {
        name  = "ApimBaseUrl"
        type  = "String"
        value = module.api_management[0].gateway_url
      }
    ] : []
  )

  # ===================================
  # RBAC Permissions
  # ===================================
  grant_key_vault_permissions = true
  grant_storage_permissions   = true

  tags = merge(
    local.common_tags,
    {
      Component = "Data Factory"
      Purpose   = "ETL/ELT pipelines for Power Platform and Azure integration"
    }
  )

  depends_on = [
    module.resource_groups,
    module.key_vault,
    module.storage_account_datafactory,
    module.app_registrations,
    module.powerplatform,
    module.network
  ]
}

# ===================================
# IMPORTANT: Network Routing for Power Platform
# ===================================
# For Data Factory to connect to Power Platform with a whitelistable IP:
#
# 1. Data Factory Managed VNet uses Azure Integration Runtime
# 2. Outbound traffic from managed VNet routes through Azure backbone
# 3. Add the following to Power Platform IP firewall allowlist:
#    - NAT Gateway Public IP: ${module.network.nat_public_ip_address}
#
# NOTE: Data Factory managed VNet does NOT directly use the NAT Gateway
# However, if using Self-Hosted Integration Runtime on VMs in your VNet,
# that traffic WILL route through the NAT Gateway.
#
# For managed VNet scenarios, you may need to:
# - Use Self-Hosted IR on a VM in subnet-nat (routes through NAT Gateway)
# - OR whitelist Azure Data Factory service tags in Power Platform
# - OR use private endpoints with Power Platform Enterprise Policy

# ===================================
# Output Data Factory Information
# ===================================

output "data_factory_id" {
  description = "Data Factory resource ID"
  value       = var.enable_data_factory ? module.data_factory[0].data_factory_id : null
}

output "data_factory_name" {
  description = "Data Factory name"
  value       = var.enable_data_factory ? module.data_factory[0].data_factory_name : null
}

output "data_factory_principal_id" {
  description = "Data Factory managed identity principal ID"
  value       = var.enable_data_factory ? module.data_factory[0].data_factory_principal_id : null
}

output "data_factory_integration_runtime" {
  description = "Data Factory integration runtime name"
  value       = var.enable_data_factory ? module.data_factory[0].integration_runtime_name : null
}

output "data_factory_storage_account" {
  description = "Data Factory storage account name"
  value       = var.enable_data_factory ? module.storage_account_datafactory[0].storage_account_name : null
}

output "data_factory_nat_gateway_ip" {
  description = "NAT Gateway public IP for whitelisting in Power Platform (null if NAT Gateway or Data Factory disabled)"
  value       = var.enable_data_factory && var.enable_nat_gateway ? module.network.nat_public_ip_address : null
}
