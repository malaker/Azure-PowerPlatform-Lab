# Power Platform Integration - Terraform Infrastructure

This directory contains the Terraform infrastructure-as-code for Power Platform and Azure integration.

## Quick Start

```powershell
# Initialize Terraform (first time only)
.\deploy.ps1 -Init -Environment dev

# Plan deployment
.\deploy.ps1 -Environment dev -Action plan

# Apply deployment
.\deploy.ps1 -Environment dev -Action apply
```

## Project Structure

```
terraform/
├── README.md                       # This file
├── deploy.ps1                      # Deployment automation script
├── .gitignore                      # Git ignore patterns
│
├── Core Files
│   ├── main.tf                     # Main orchestration
│   ├── variables.tf                # Variable declarations
│   ├── locals.tf                   # Local values and naming
│   ├── providers.tf                # Provider configuration
│   ├── versions.tf                 # Version constraints
│   └── outputs.tf                  # Output definitions
│
├── Resources                       # Resource-specific configurations
│   ├── api-management.tf           # API Management
│   ├── data-factory.tf             # Data Factory
│   ├── function-app.tf             # Azure Functions
│   ├── logic-apps.tf               # Logic App Standard
│   ├── network.tf                  # Networking (VNet, subnets, DNS)
│   └── power-platform.tf           # Power Platform environments
│
├── modules/                        # Reusable modules (13 modules)
│   ├── api-management/
│   ├── app-registrations/
│   ├── data-factory/
│   ├── function-app-flex/
│   ├── key-vaults/
│   ├── log-analytics/
│   ├── logic-app-connections/
│   ├── logic-app-standard/
│   ├── network/
│   ├── power-platform/
│   ├── power-platform-enterprise-policy/
│   ├── resource-groups/
│   └── storage-account/
│
├── environments/                   # Environment-specific configs
│   └── dev/terraform.tfvars
│
└── bff-openapi/                    # OpenAPI specifications
    └── pp-bff.json


```

## What Gets Created

This Terraform configuration deploys a comprehensive Azure and Power Platform integration infrastructure with feature flags for optional components.

### Cost Overview

#### Current Configuration (Dev Environment - Default Settings)
Based on `terraform.tfvars` with current feature flags:
- **Total Monthly Cost: ~$0-15/month** (excluding Power Platform Developer env which is free)
  - ✅ Core Infrastructure: ~$0/month (Free tier: Function App Flex, Key Vault, Storage)
  - ✅ Networking: ~$0/month (VNet, subnets, NSGs are free)
  - ❌ NAT Gateway: Disabled (saves ~$36.50/month)
  - ❌ API Management: Disabled (saves ~$48.04/month)
  - ❌ Logic App Standard: Disabled (saves ~$197/month)
  - ❌ Data Factory: Disabled (saves ~$2-10/month)
  - ✅ Power Platform Developer Environment: Free
  - ✅ Subnet Delegation (Enterprise Policy): Enabled (~$0/month - no direct cost)

#### Full Configuration (All Features Enabled)
With all feature flags enabled:
- **Total Monthly Cost: ~$283-295/month** (in Dev environment)
  - Core Infrastructure: ~$0/month
  - NAT Gateway: ~$36.50/month
  - API Management (Developer_1): ~$48.04/month
  - Logic App Standard (WS1): ~$197/month
  - Data Factory: ~$2-10/month (usage-based)
  - Power Platform Developer Environment: Free
  - Subnet Delegation (Enterprise Policy): ~$0/month

> **Note:** Costs are estimates for West Europe region (as of 2024) and may vary based on usage, region, and Azure pricing changes. Function App Flex Consumption and Storage are usage-based with generous free tiers.

---

### 📦 Core Resources (Always Created)

These resources are created in every deployment:

#### Resource Groups (5)
- `rg-dev-keyvaults` - Key Vault resources for secrets management
- `rg-dev-network` - Virtual networks, subnets, NSGs, NAT Gateway
- `rg-dev-logicapps` - Logic Apps and integration workflows
- `rg-dev-functions` - Azure Functions and dedicated storage accounts
- `rg-dev-datafactory` - Azure Data Factory for ETL/ELT pipelines
- `NetworkWatcherRG` - Network Watcher resources (auto-created by Azure)

#### Entra ID (Azure AD) App Registrations (4)
- **az-function-backend** - Azure Functions backend API
  - Exposes OAuth2 delegated scope (`access_as_user`)
  - Exposes application role (`API.Access.All`)
  - Dynamics 365 CRM `user_impersonation` permission

- **power-platform-svc** - Service principal for Power Platform Dataverse plugins
  - API permissions to `az-function-backend` (delegated + application)
  - Dynamics 365 CRM `user_impersonation` permission
  - Federated identity credentials for plugin authentication

- **logic-app-dataverse-svc** - Service principal for Logic Apps → Dataverse
  - Dynamics 365 CRM `user_impersonation` permission

- **data-factory-dataverse-svc** - Service principal for Data Factory → Dataverse
  - Dynamics 365 CRM `user_impersonation` permission

All app registration secrets are automatically stored in Key Vault.

#### Networking
- **Virtual Network (West Europe)**: `dev-pplab01-vnet-weu` (10.0.0.0/16)
  - `subnet-powerplatform` (10.0.1.0/24) - For Power Platform VNet integration
  - `subnet-logicapps` (10.0.2.0/24) - For Logic App Standard outbound integration
  - `subnet-apim` (10.0.3.0/24) - For API Management
  - `subnet-functions` (10.0.4.0/24) - For Azure Functions outbound integration
  - `subnet-storage` (10.0.5.0/24) - Reserved for storage private endpoints
  - `subnet-nat` (10.0.6.0/24) - Reserved for NAT Gateway scenarios

- **Network Security Groups (NSGs)** - One per subnet with appropriate rules
- **Service Endpoints** - Configured on subnets for Key Vault and Storage

#### Security & Secrets
- **Azure Key Vault** - Centralized secrets management
  - RBAC-based access control (no legacy access policies)
  - Network rules allowing VNet subnets only
  - 7-day soft delete retention (dev), 90 days (prod)
  - Stores all app registration secrets with Key Vault references

#### Compute & Functions
- **Azure Function App (Flex Consumption)** - Serverless API backend
  - VNet integration for outbound traffic
  - Managed identity authentication to Storage (RBAC, no connection strings)
  - Key Vault integration via Key Vault references
  - Application Insights for monitoring
  - Inbound access restrictions (APIM or Power Platform subnets)
  - Dataverse configuration pre-configured in app settings

- **Storage Account (Functions)** - Dedicated storage for Function App
  - Network rules: Allow VNet subnets only (deny public access)
  - RBAC roles granted to Function App managed identity
  - Soft delete enabled (7 days dev, 30 days prod)

- **Log Analytics Workspace** - Centralized logging for Application Insights
  - 30-day retention (dev), 90-day retention (prod)

---

### 🎛️ Optional Resources (Controlled by Feature Flags)

#### NAT Gateway (`enable_nat_gateway = false`)
**Cost:** ~$36.50/month

When enabled, creates:
- Public IP address (static, zone-redundant)
- NAT Gateway in zone 1
- Provides static outbound IP for whitelisting in Power Platform IP firewall
- Can be associated with subnets for consistent outbound IP

**Use Case:** Required when Power Platform IP firewall needs to whitelist Azure services

---

#### Power Platform Subnet Delegation (`enable_powerplatform_subnet_delegation = true`)
**Cost:** ~$0/month (no direct cost for enterprise policy)

When enabled, creates:
- **Virtual Network (North Europe)**: `dev-pplab01-vnet-neu` (10.1.0.0/16)
  - `subnet-powerplatform` (10.1.1.0/24) with delegation to `Microsoft.PowerPlatform/enterprisePolicies`
  - Network Security Group for the subnet
- **VNet Peering** between West Europe and North Europe VNets
- **Power Platform Enterprise Policy** linking both subnets
- **Resource Group (North Europe)**: `rg-dev-network-northeurope`
- **Network Watcher (North Europe)**: For monitoring

**Requirements:**
- Minimum 2 subnets in paired Azure regions (West Europe + North Europe)
- Required for Power Platform VNet integration and managed environments

**Use Case:** Private connectivity between Power Platform and Azure services via VNet

---

#### Power Platform Environments (`power_platform_environments` list)
**Cost:** Developer environments are FREE

When configured, creates:
- **Power Platform Developer Environment** (or Sandbox/Production based on config)
  - Dataverse database with specified language/currency
  - Managed environment features (when `enable_managed_environment = true`)
  - Enterprise policy VNet integration (when subnet delegation enabled)
  - NAT Gateway public IP added to IP firewall allowlist (when NAT Gateway enabled)

- **Application Users** in Dataverse:
  - Primary app registration (e.g., `power-platform-svc`)
  - Additional app registrations (e.g., `az-function-backend`, `logic-app-dataverse-svc`, `data-factory-dataverse-svc`)
  - Assigned security roles (e.g., "Service Reader", "Service Writer")

- **Federated Identity Credentials**:
  - Automatic credential creation for Dataverse plugin authentication
  - Supports both production (CA-signed certs) and development (self-signed certs) modes

- **Solution Import** (optional):
  - Automated packing of custom solutions with token replacement
  - Import of pre-packaged solutions
  - Plugin activation

**Current Config:** 1x Developer environment (`pplab01-dev`) with managed environment features

---

#### API Management (`enable_api_management = false`)
**Cost:** ~$48.04/month (Developer_1 SKU)

When enabled, creates:
- **Azure API Management** (Developer_1 tier with VNet support)
  - Internal VNet integration (private endpoint only by default)
  - Dedicated subnet (`subnet-apim`)
  - Optional public IP for External VNet mode
  - BFF (Backend for Frontend) API from OpenAPI spec
  - OAuth 2.0 validation with Azure AD
  - Backend connection to Azure Functions

- **Private DNS Zone** (Internal mode only):
  - Specific hostname zone (e.g., `dev-pplab01-apim-weu-xxxx.azure-api.net`)
  - DNS A record mapping to APIM private IP
  - VNet links to both West Europe and North Europe VNets (if delegation enabled)

**Use Case:** API gateway for Power Platform to access Azure Functions with policies, throttling, and OAuth

---

#### Logic App Standard (`enable_logic_apps = false`)
**Cost:** ~$197/month (WS1 App Service Plan)

When enabled, creates:
- **Shared App Service Plan (WS1)** - Windows Workflow Standard tier
  - Can be upgraded to WS2/WS3 for more resources

- **Shared Storage Account** - For all Logic App instances
  - Network rules: Allow Logic Apps and Power Platform subnets
  - Soft delete enabled

- **Logic App Standard** - Workflow hosting
  - VNet integration for outbound traffic (`subnet-logicapps`)
  - Inbound IP restrictions (Power Platform subnets + `PowerPlatformInfra` service tag)
  - User-assigned managed identity for reliability
  - Pre-configured app settings for Dataverse and APIM

- **API Connections**:
  - **Dataverse (CDS) Connection** - Service principal authentication
  - Secrets stored in Key Vault with references
  - Access policies for Logic App managed identities

- **Network Rules**:
  - CRITICAL: Allows `PowerPlatformInfra` service tag for Dataverse triggers
  - Power Platform subnets (both regions) for custom connectors/HTTP actions

**Workflow Deployment:** Terraform creates infrastructure; workflows deployed separately via VS Code/Azure CLI

**Use Case:** Low-code integration workflows between Power Platform, Dataverse, and Azure services

---

#### Data Factory (`enable_data_factory = false`)
**Cost:** ~$2-10/month (usage-based)

When enabled, creates:
- **Azure Data Factory** with managed VNet
  - Azure Integration Runtime (8 cores General compute, 5-min TTL)
  - Managed private endpoints to Storage and Key Vault
  - System-assigned managed identity

- **Dedicated Storage Account** - For staging and intermediate data
  - Network rules: Allow Power Platform subnets

- **Linked Services**:
  - Storage Account (ADLS Gen2)
  - Key Vault (for secrets)
  - Dataverse (service principal auth via Key Vault)
  - APIM (if enabled)

- **Global Parameters**:
  - Environment name
  - Dataverse URL
  - APIM Base URL (if enabled)
  - NAT Gateway Public IP (if enabled)

- **RBAC Permissions**:
  - Key Vault Secrets User (for secret access)
  - Storage Blob Data Contributor (for data access)

**Network Note:** Managed VNet uses Azure backbone. For whitelistable IP, enable NAT Gateway or use Self-Hosted IR.

**Use Case:** ETL/ELT pipelines for data integration between Power Platform and Azure services

---

### 🔐 Security & RBAC

#### Key Vault Access (RBAC-based)
- **Admin:** Current user/service principal (Key Vault Administrator)
- **Function App:** Key Vault Secrets User
- **Logic Apps:** Key Vault Secrets User (if enabled)
- **Data Factory:** Key Vault Secrets User (if enabled)
- **Power Platform SVC:** Key Vault Secrets User

#### Storage Account Access (RBAC-based)
- **Function App:** Storage Blob/Queue/Table Data Contributor
- **Logic Apps:** Storage Blob/Queue/Table Data Contributor (if enabled)
- **Data Factory:** Storage Blob Data Contributor (if enabled)

#### API Permissions (Auto-granted)
- **power-platform-svc → az-function-backend:**
  - Delegated: `access_as_user` (OAuth2 scope) ✅ Admin consent granted
  - Application: `API.Access.All` (App role) ✅ Admin consent granted

#### Network Access Control
- **Key Vault:** VNet subnets only (all Power Platform, Logic Apps, Functions, APIM)
- **Storage Accounts:** VNet subnets only + AzureServices bypass
- **Function App:** Inbound restricted to APIM or Power Platform subnets
- **Logic Apps:** Inbound restricted to Power Platform subnets + `PowerPlatformInfra` service tag

---

### 📊 Feature Flag Summary

| Feature | Variable | Default | Monthly Cost |
|---------|----------|---------|--------------|
| NAT Gateway | `enable_nat_gateway` | `false` | ~$36.50 |
| Power Platform Subnet Delegation | `enable_powerplatform_subnet_delegation` | `true` | ~$0 |
| API Management | `enable_api_management` | `false` | ~$48.04 |
| Logic App Standard | `enable_logic_apps` | `false` | ~$197 |
| Data Factory | `enable_data_factory` | `false` | ~$2-10 |

**Current Total:** ~$0-15/month (only core + subnet delegation)
**All Features Enabled:** ~$283-295/month

---

### 🌍 Multi-Region Setup

When subnet delegation is enabled, the infrastructure spans two paired Azure regions for high availability:

#### West Europe (Primary)
- Virtual Network (10.0.0.0/16)
- All Azure resources (Functions, Storage, Key Vault, etc.)
- Power Platform subnet (10.0.1.0/24)
- APIM, Logic Apps, Functions subnets

#### North Europe (Paired Region)
- Virtual Network (10.1.0.0/16)
- Power Platform subnet (10.1.1.0/24)
- VNet peering to West Europe
- Required for Power Platform Enterprise Policy

---

### 📝 Naming Conventions

All resources follow Azure naming best practices:

| Resource Type | Pattern | Example |
|--------------|---------|---------|
| Resource Group | `rg-{env}-{purpose}` | `rg-dev-keyvaults` |
| VNet | `{env}-{project}-vnet-{region}` | `dev-pplab01-vnet-weu` |
| Subnet | `subnet-{purpose}` | `subnet-powerplatform` |
| Key Vault | `{env}-{project}-kv-{region}-{random}` | `dev-pplab-kv-weu-a1b2` |
| Storage Account | `{env}{project}{purpose}{region}{random}` | `devpplab01funcweua1b2` |
| Function App | `{env}-{project}-func-{region}` | `dev-pplab01-func-weu` |
| APIM | `{env}-{project}-apim-{region}-{random}` | `dev-pplab01-apim-weu-c79b` |
| Logic App | `{env}-{project}-logicapp-{region}` | `dev-pplab01-logicapp-weu` |
| Data Factory | `{env}-{project}-adf-{region}` | `dev-pplab01-adf-weu` |

**Random Suffix:** 4-character hex ensures global uniqueness for shared/open-source code

---

### 🔍 Verification

After deployment, verify resources were created:

```powershell
# View all created resources
.\deploy.ps1 -Environment dev -Action show

# Verify specific outputs
terraform output resource_group_names
terraform output app_client_ids
terraform output function_app_name
terraform output power_platform_environment_urls
```


