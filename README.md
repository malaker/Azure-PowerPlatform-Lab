# Azure & Power Platform Integration Lab

> **A comprehensive lab environment for testing Power Platform premium features with Azure integration using managed identities, VNet integration, and enterprise security patterns.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoftazure)](https://azure.microsoft.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5%2B-623CE4?logo=terraform)](https://www.terraform.io/)
[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![Power Platform](https://img.shields.io/badge/Power%20Platform-Dataverse-742774?logo=powerapps)](https://powerplatform.microsoft.com/)

## 🎯 Purpose

This repository provides a **quick and automated way** to provision Azure and Power Platform resources for:

- ✅ **Testing Power Platform premium features** (Managed Environments, VNet Integration, Enterprise Policies)
- ✅ **Learning enterprise integration patterns** between Power Platform and Azure
- ✅ **Demonstrating managed identity authentication** (no secrets in code!)
- ✅ **Exploring secure networking** (VNets, Private Endpoints, Firewalls, NAT Gateway)
- ✅ **Building production-like architectures** with minimal cost (~$0-15/month default config)

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Power Platform                              │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Dataverse Environment (Developer - FREE)                     │   │
│  │  • Managed Environment Features                              │   │
│  │  • VNet Integration (Enterprise Policy)                      │   │
│  │  • Custom APIs (Dataverse Plugins with Managed Identity)     │   │
│  │  • Federated Identity Credentials (workload identity)        │   │
│  └─────────────────┬────────────────────────────────────────────┘   │
└────────────────────┼────────────────────────────────────────────────┘
                     │ Private Connectivity
┌────────────────────┼────────────────────────────────────────────────┐
│                    │              Azure                             │
│  ┌─────────────────▼────────────────────────────────────────────┐   │
│  │ VNet (West Europe + North Europe paired regions)             │   │
│  │  • Subnet Delegation for Power Platform                      │   │
│  │  • Private DNS Zones                                         │   │
│  │  • Network Security Groups                                   │   │
│  │  • NAT Gateway (optional - whitelistable IP)                 │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              Optional              Optional         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐    │
│  │  Azure Functions │  │  Logic App Std   │  │  Data Factory   │    │
│  │  (.NET 8 Flex)   │  │  (Workflows)     │  │  (Managed VNet) │    │
│  │  • VNet Integration  • VNet Integration│  │  • Dataverse    │    │
│  │  • OAuth2 + OBO  │  │  • Dataverse     │  │    Linked Svc   │    │
│  │  • RBAC Auth     │  │    Connector     │  │  • RBAC Auth    │    │
│  └──────────────────┘  └──────────────────┘  └─────────────────┘    │
│          Optional                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐    │
│  │  API Management  │  │  Key Vault       │  │  Storage Accts  │    │
│  │  (BFF Pattern)   │  │  (RBAC-based)    │  │  (RBAC-based)   │    │
│  │  • Internal VNet │  │  • VNet Rules    │  │  • VNet Rules   │    │
│  │  • OAuth Validation │  • Secrets Mgmt  │  │  • Private EP   │    │
│  └──────────────────┘  └──────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

## 📁 Repository Structure

```
Azure-PowerPlatform-Lab/
├── README.md                                      # This file
├── LICENSE                                        # MIT License
├── .gitignore                                     # Git ignore patterns
│
├── Infrastructure/                                # Terraform IaC
│   └── terraform/
│       ├── README.md                              # Detailed infrastructure docs
│       ├── deploy.ps1                             # Deployment automation script
│       ├── main.tf                                # Core orchestration
│       ├── variables.tf                           # Variable declarations
│       ├── locals.tf                              # Local values and naming
│       ├── providers.tf                           # Provider configuration
│       ├── versions.tf                            # Version constraints
│       ├── outputs.tf                             # Output definitions
│       │
│       ├── Resources/                             # Resource-specific configs
│       │   ├── api-management.tf                  # API Management
│       │   ├── data-factory.tf                    # Data Factory
│       │   ├── function-app.tf                    # Azure Functions
│       │   ├── logic-apps.tf                      # Logic App Standard
│       │   ├── network.tf                         # VNet, subnets, DNS
│       │   └── power-platform.tf                  # Power Platform envs
│       │
│       ├── modules/                               # 13 reusable modules
│       │   ├── api-management/
│       │   ├── app-registrations/
│       │   ├── data-factory/
│       │   ├── function-app-flex/
│       │   ├── key-vaults/
│       │   ├── log-analytics/
│       │   ├── logic-app-connections/
│       │   ├── logic-app-standard/
│       │   ├── network/
│       │   ├── power-platform/
│       │   ├── power-platform-enterprise-policy/
│       │   ├── resource-groups/
│       │   └── storage-account/
│       │
│       ├── environments/                          # Environment configs
│       │   └── dev/terraform.tfvars
│       │
│       ├── bff-openapi/                           # OpenAPI specs
│           └── pp-bff.json
│
│
│
│
│
│
│
│
└── Source/                                        # Application code
    ├── IntegrationGuide.slnx                      # Visual Studio solution
    │
    ├── Azure/                                     # Azure components
    │   ├── Functions/
    │   │   └── FnBackend/                         # .NET 8 Isolated Function App
    │   │       ├── Functions/                     # HTTP-triggered functions
    │   │       ├── Services/                      # Dataverse service client
    │   │       ├── Middleware/                    # OAuth2 validation
    │   │       └── Deployment/                    # Deployment scripts
    │   │           └── deploy.ps1                 # Function app code deployment script
    │   │
    │   │
    │   │
    │   ├── LogicApps/
    │   │   ├── Workflows/                         # Logic App Standard workflows
    │   │   │   ├── DataverseIntegration/
    │   │   │   │   └── workflow.json
    |   |   |   ├── DataverseTrigger/
    │   │   │   │   └── workflow.json
    │   │   │   │   
    │   │   │   ├── host.json
    |   |   |   ├── connections.json
    |   |   |   └── parameters.json
    │   │   │ 
    │   │   └── Deployment/
    |   |       └── deploy.ps1                     # Logic App Workflows deployment script
    │   │
    │   └── AzureDataFactory/
    │       ├── adf_export/                        # Exported ADF artifacts
    │       │   ├── datasets/                      # Dataverse datasets
    │       │   └── pipelines/                     # Import pipelines
    │       ├── data/                              # Sample data files
    │       └── Deployment/                        # Import automation
    │
    └── PowerPlatform/                             # Power Platform components
        ├── Plugin/                                # Dataverse Plugin (.NET 4.6.2)
        │   ├── AzKeyVaultDemoPlugin.cs            # Azure Key Vault integration
        │   ├── GenericHttpClientDemoPlugin.cs     # HTTP client with MI
        │   ├── PluginBase.cs
        │   └── Services/
        │       ├── AzKeyVaultService.cs
        │       └── GenericHttpClient.cs
        │
        └── Solutions/
            └── pplab01/
                ├── src_template/                  # Template with token placeholders, Unpacked solution source
                │   ├── customapis/                # Custom APIs
                │   │   ├── kb_AzKeyVaultDemoApi/
                │   │   └── kb_GenericHttpClient/
                │   ├── pluginpackages/
                │   └── Other/
                ├── src/                           # terraform apply will output here unpacked solution with replaced tokens
                └── packed/                        # Packed solution ZIP after terraform apply command
                    
```

## 🚀 Quick Start

### Prerequisites

- **Azure Subscription** with Owner or Contributor + User Access Administrator roles
- **Power Platform License** (Developer environment is FREE, or M365 trial)
- **Terraform** 1.5+ ([Install](https://www.terraform.io/downloads))
- **Azure CLI** ([Install](https://docs.microsoft.com/cli/azure/install-azure-cli))
- **Power Platform CLI** (terraform power platform module requires this to configure managed environment since native tf provider has some bugs)
- **.NET 8 SDK** ([Install](https://dotnet.microsoft.com/download/dotnet/8.0))
- **Visual Studio 2022 or VS Code** (for source code development)

### 1️⃣ Deploy Infrastructure (5-10 minutes with minimal configuration, 30-45 minutes with all resources)

```powershell
# Clone repository
git clone https://github.com/malaker/Azure-PowerPlatform-Lab.git
cd Azure-PowerPlatform-Lab/Infrastructure/terraform


# Configure environment
# Edit environments/dev/terraform.tfvars with your settings:
# - subscription_id
# - default_power_platform_owner_id (your Entra ID user GUID)
# - apim_publisher_email (if enabling APIM)

# Login to Azure
az login

# Initialize Terraform (first time only)
.\deploy.ps1 -Init -Environment dev

# Review what will be created
.\deploy.ps1 -Environment dev -Action plan

# Deploy infrastructure
.\deploy.ps1 -Environment dev -Action apply

# View outputs (URLs, client IDs, etc.)
terraform output
```

**What gets deployed:**
- 5 Resource Groups
- 4 App Registrations (one with federated credentials)
- VNet with 6 subnets + NSGs
- Key Vault (RBAC-based) that includes client id and secrets
- Azure Function App (Flex Consumption)
- Storage Accounts (RBAC-based)
- Log Analytics + Application Insights
- Power Platform Developer Environment
- Enterprise Policy + VNet Integration

**💰 Default Cost: ~$0-15/month**

### 2️⃣ Deploy Source Code

#### Deploy Azure Functions

```powershell
cd Source/Azure/Functions/FnBackend/Deployment

#Since terraform generates everytime unique resource names either get function app name from portal azure or terraform outputs
.\deploy.ps1 -FunctionAppName <function resource name>

```

#### Deploy Logic App Workflows (optional)

```powershell
cd Source/Azure/LogicApps/Deployment

.\deploy.ps1 -LogicAppStandardResourceName <logic app resource name>

```

#### Deploy Data Factory Artifacts

```powershell
cd Source/Azure/AzureDataFactory/Deployment

# Import datasets and pipelines
.\deploy.ps1 -AdfResourceName <ADF resource name>

```

#### Deploy Power Platform Solution

The solution is automatically packed by Terraform if the source exists.

Deploy solution manually or using PAC CLI

## 💰 Cost Breakdown

### Current Configuration (Default `terraform.tfvars`)
**~$0-15/month** in Dev environment

| Component | Status | Monthly Cost |
|-----------|--------|--------------|
| Core Infrastructure (Functions*, Storage, Key Vault) | ✅ Enabled | ~$0 (Free tier) |
| Networking (VNet, NSGs, VNet Peering**) | ✅ Enabled | ~$0-5 (Traffic-based) |
| NAT Gateway | ❌ Disabled | Saves ~$36.50 |
| API Management (Developer_1) | ❌ Disabled | Saves ~$48.04 |
| Logic App Standard (WS1) | ❌ Disabled | Saves ~$197 |
| Data Factory | ❌ Disabled | Saves ~$2-10 |
| Power Platform Developer Env | ✅ Enabled | $0 (Free) |
| Subnet Delegation (Enterprise Policy) | ✅ Enabled | $0 (Free) |

**\* Azure Functions (Flex Consumption Plan):** Includes a generous free monthly grant of 250,000 executions and 100,000 GB-seconds per subscription. Beyond the free tier, costs are $0.000026/GB-s for execution time and $0.40 per million executions. For typical dev/demo workloads, you'll likely stay within the free tier.

**\*\* VNet Peering:** Cross-region VNet peering (West Europe ↔ North Europe) incurs data transfer charges at ~$0.035/GB for both inbound and outbound traffic. VNets and NSGs themselves are free, but peering costs depend on traffic volume between regions. For minimal dev/demo traffic, costs are typically under $5/month.

### All Features Enabled
**~$283-295/month** in Dev environment

See [Infrastructure README](Infrastructure/terraform/README.md#cost-overview) for detailed cost analysis.

## 🎛️ Feature Flags

Control what gets deployed via `environments/dev/terraform.tfvars`:

```hcl
# Network
enable_nat_gateway = false                           # ~$36.50/month - Static IP for whitelisting
enable_powerplatform_subnet_delegation = true        # Free - VNet integration

# Azure Services
enable_api_management = false                        # ~$48.04/month - API Gateway
enable_logic_apps = false                            # ~$197/month - Low-code workflows
enable_data_factory = false                          # ~$2-10/month - ETL/ELT pipelines

# Power Platform
power_platform_environments = [...]                  # Free for Developer
```

## 🔐 Key Features & Integration Patterns

### 1. Managed Identity Authentication (No Secrets!)

**Dataverse Plugin → Azure Key Vault:**
- Federated Identity Credentials (Workload Identity)
- No client secrets in code or environment variables

**APIM (Optional) → Azure Functions → Dataverse:**
- Service Principal with OAuth2
- On-Behalf-Of (OBO) flow for user context                      # Custom connector to be defined manually in maker portal
- Client credentials flow for app-only scenarios

**Logic Apps → Dataverse:**
- Managed Identity with API Connections
- Service Principal authentication
- Secrets stored in Key Vault (via references)     
- Networking configuration (Firewall+VNET outbound integration)  # Since Dataverse connector does not use subnet delegation, to function correctly Dataverse Trigger for Logic App it is required to whitelist either Service Tag: PowerPlatformInfra or individual Power Platform IPs which is very error prone.

**Data Factory → Dataverse:**
- Managed Identity with linked services
- Service Principal authentication
- Key Vault integration for credentials
- VNET Integration

### 2. Enterprise Networking Patterns

**VNet Integration:**
- Subnet delegation for Power Platform
- Private connectivity between Azure and Dataverse
- No public internet traversal

**Network Security:**
- NSGs on all subnets
- Network access restrictions on Functions/Logic Apps
- Private DNS zones for internal APIM
- Service endpoints for Key Vault and Storage

**Outbound IP Control:**
- Optional NAT Gateway for static IP
- Whitelistable IP for Power Platform IP firewall
- Consistent outbound connectivity

### 3. Security Best Practices

**Zero Trust Principles:**
- RBAC-based access control (no legacy access policies)
- Managed identities everywhere (no connection strings)
- Key Vault for all secrets
- Network isolation with VNets

**Least Privilege Access:**
- Function App: Only Key Vault Secrets User + Storage Contributor
- Logic Apps: Only required API Connection access
- Data Factory: Only linked service permissions
- Power Platform SVC: Only required API permissions

**API Security:**
- OAuth2 + JWT validation on Azure Functions
- API Management with OAuth policies
- App roles for application permissions
- Delegated scopes for user context



## 🧪 What Can You Test?

### Power Platform Premium Features
- ✅ Managed Environments
- ✅ VNet Integration (Enterprise Policies)
- ✅ Dataverse Plugins with Managed Identity
- ✅ Custom APIs
- ✅ IP Firewall with NAT Gateway (optional)

### Azure Integration Patterns
- ✅ Azure Functions with OAuth2 + OBO flow
- ✅ Logic App Standard with Dataverse triggers
- ✅ Data Factory ETL/ELT pipelines
- ✅ API Management BFF pattern
- ✅ Key Vault integration (no secrets in code!)
- ✅ VNet private connectivity

### Security Scenarios
- ✅ Managed Identity end-to-end
- ✅ RBAC-based access control
- ✅ Network isolation with VNets
- ✅ OAuth2 token validation
- ✅ App roles + delegated permissions
- ✅ Key Vault secret management


## 🧹 Cleanup

To delete all resources:

```powershell
cd Infrastructure/terraform

# Destroy all infrastructure
.\deploy.ps1 -Environment dev -Action destroy

# Confirm with 'destroy-dev'

# Confirm with 'yes'
```

**Note:** Power Platform environments may have deletion protection enabled. Manually delete in Power Platform Admin Center if needed. Remember to unlink enterprise policy in the first place in case of manual deletion resources.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


**⭐ If this repository helped you, please consider giving it a star!**
