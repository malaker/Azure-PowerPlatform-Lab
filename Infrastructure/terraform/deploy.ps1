<#
.SYNOPSIS
    Terraform deployment script for Azure and Power Platform infrastructure with cost analysis.

.DESCRIPTION
    This script manages Terraform deployments across different environments (dev, qa, prod).
    Supports plan, apply, destroy operations with proper validation and error handling.

    Features:
    - Comprehensive cost analysis before deployment
    - Environment-specific pricing estimates
    - Automatic Azure AD user GUID retrieval for dev environments
    - Safety checks for production deployments
    - Detailed resource breakdown

.PARAMETER Environment
    Target environment: dev, qa, or prod (default: dev)

.PARAMETER Action
    Action to perform: plan, apply, destroy, output, validate, or cost-estimate (default: plan)

.PARAMETER AutoApprove
    Skip interactive approval for apply/destroy operations

.PARAMETER Init
    Run terraform init before the action

.PARAMETER ShowCostBreakdown
    Display detailed cost breakdown before plan/apply operations

.EXAMPLE
    .\deploy.ps1 -Environment dev -Action plan -ShowCostBreakdown
    Runs a dry-run plan for dev environment with cost breakdown

.EXAMPLE
    .\deploy.ps1 -Environment dev -Action apply
    Applies changes to dev environment with approval prompt

.EXAMPLE
    .\deploy.ps1 -Environment prod -Action apply -AutoApprove
    Applies changes to prod environment without approval prompt

.EXAMPLE
    .\deploy.ps1 -Action cost-estimate -Environment qa
    Shows detailed cost estimate for QA environment without running Terraform

.NOTES
    Cost estimates are based on Azure pricing as of November 2025.
    Actual costs may vary based on usage patterns and data transfer.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev')]
    [string]$Environment = 'dev',

    [Parameter(Mandatory = $true)]
    [ValidateSet('plan', 'apply', 'destroy', 'output', 'validate', 'cost-estimate')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$AutoApprove,

    [Parameter(Mandatory = $false)]
    [switch]$Init,

    [Parameter(Mandatory = $false)]
    [switch]$ShowCostBreakdown,

    [Parameter(Mandatory = $false)]
    [string]$az_login_interactive
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Script configuration
$ScriptDir = $PSScriptRoot
$TerraformDir = $ScriptDir
$EnvironmentDir = Join-Path $TerraformDir "environments\$Environment"
$VarFile = Join-Path $EnvironmentDir "terraform.tfvars"

#region Color Output Functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info { param([string]$Message) Write-ColorOutput "INFO: $Message" -Color Cyan }
function Write-Success { param([string]$Message) Write-ColorOutput "SUCCESS: $Message" -Color Green }
function Write-Warning { param([string]$Message) Write-ColorOutput "WARNING: $Message" -Color Yellow }
function Write-Error { param([string]$Message) Write-ColorOutput "ERROR: $Message" -Color Red }
function Write-Section { param([string]$Message) Write-ColorOutput "`n=== $Message ===" -Color Magenta }
function Write-Cost { param([string]$Message) Write-ColorOutput $Message -Color Yellow }
#endregion

#region Cost Analysis Function
function Show-CostBreakdown {
    param(
        [string]$Environment
    )

    Write-Section "ESTIMATED MONTHLY COST BREAKDOWN - $($Environment.ToUpper()) ENVIRONMENT"

    Write-ColorOutput "`nThis Terraform deployment will create the following Azure resources:" -Color White
    Write-ColorOutput "All cost estimates are in USD and based on Azure pricing as of November 2025.`n" -Color Gray

    switch ($Environment) {
        'dev' {
            Write-ColorOutput "DEVELOPMENT ENVIRONMENT - Optimized for Cost" -Color Green
            Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Color Gray
            Write-ColorOutput ""

            Write-ColorOutput "NETWORKING RESOURCES:" -Color Cyan
            Write-ColorOutput "  • Virtual Network (1x West Europe)              FREE" -Color White
            Write-ColorOutput "  • Subnets (6x in VNet)                          FREE" -Color White
            Write-ColorOutput "  • Network Security Groups (6x)                  `$3.00/month" -Color Yellow
            Write-ColorOutput "  • NAT Gateway + Public IP                       `$35.32/month" -Color Yellow
            Write-ColorOutput "    └─ Required for outbound internet access" -Color Gray
            Write-ColorOutput ""

            Write-ColorOutput "SECURITY `& IDENTITY:" -Color Cyan
            Write-ColorOutput "  • Azure Key Vault (Standard SKU)                `$0.70/month + operations" -Color Yellow
            Write-ColorOutput "    └─ 7-day soft delete, public access enabled" -Color Gray
            Write-ColorOutput "  • App Registrations (2x)                        FREE" -Color White
            Write-ColorOutput "  • Federated Identity Credentials                FREE" -Color White
            Write-ColorOutput ""

            Write-ColorOutput "COMPUTE & STORAGE:" -Color Cyan
            Write-ColorOutput "  • Storage Account - Functions (Standard LRS)    `$2-5/month" -Color Yellow
            Write-ColorOutput "    └─ Function App backend storage" -Color Gray
            Write-ColorOutput "  • Function App (Flex Consumption)               `$10-30/month" -Color Yellow
            Write-ColorOutput "    └─ 512MB memory, max 40 instances" -Color Gray
            Write-ColorOutput "    └─ VNet integrated with NAT Gateway" -Color Gray
            Write-ColorOutput ""

            Write-ColorOutput "LOGIC APPS (Optional - disabled by default):" -Color Magenta
            Write-ColorOutput "  • Storage Account - Logic Apps (Standard LRS)   `$2-5/month" -Color Gray
            Write-ColorOutput "    └─ Shared storage for Logic App workflows" -Color Gray
            Write-ColorOutput "  • Logic App Standard (WS1)                      `$196.83/month" -Color Gray
            Write-ColorOutput "    └─ Workflow Standard plan, 1 instance" -Color Gray
            Write-ColorOutput "    └─ VNet integration, managed identity" -Color Gray
            Write-ColorOutput ""

            Write-ColorOutput "DATA FACTORY (Optional - disabled by default):" -Color Magenta
            Write-ColorOutput "  • Storage Account - Data Factory (Standard LRS) `$2-5/month" -Color Gray
            Write-ColorOutput "    └─ Data Factory staging and intermediate data" -Color Gray
            Write-ColorOutput "  • Azure Data Factory                            `$2-10/month" -Color Gray
            Write-ColorOutput "    └─ Managed VNet, pay-per-activity" -Color Gray
            Write-ColorOutput "    └─ Low usage: ~`$2-5, Medium: ~`$5-10" -Color Gray
            Write-ColorOutput ""

            Write-ColorOutput "MONITORING `& LOGGING:" -Color Cyan
            Write-ColorOutput "  • Log Analytics Workspace (PerGB2018)           `$5-15/month" -Color Yellow
            Write-ColorOutput "    └─ 30-day retention, pay-per-GB ingestion" -Color Gray
            Write-ColorOutput "  • Application Insights                          FREE (included)" -Color White
            Write-ColorOutput ""

            Write-ColorOutput "API MANAGEMENT (Optional):" -Color Cyan
            Write-ColorOutput "  • API Management (Developer SKU)                `$49.56/month" -Color Yellow
            Write-ColorOutput "    └─ Internal VNet mode, OAuth JWT validation" -Color Gray
            Write-ColorOutput "    └─ Enable with: enable_api_management = true" -Color Gray
            Write-ColorOutput ""

            Write-ColorOutput "POWER PLATFORM:" -Color Cyan
            Write-ColorOutput "  • Power Platform Environment (Developer)        FREE" -Color Green
            Write-ColorOutput "    └─ Includes Dataverse database" -Color Gray
            Write-ColorOutput "  • Application User (Service Principal)          FREE" -Color White
            Write-ColorOutput ""

            Write-ColorOutput "INTEGRATION RESOURCES:" -Color Cyan
            Write-ColorOutput "  • Logic App API Connections (Dataverse)         FREE" -Color White
            Write-ColorOutput "    └─ Managed API connections for workflows" -Color Gray
            Write-ColorOutput ""

            Write-ColorOutput "OTHER RESOURCES:" -Color Cyan
            Write-ColorOutput "  • Resource Groups (4x)                          FREE" -Color White
            Write-ColorOutput "  • Network Watcher                               FREE" -Color White
            Write-ColorOutput ""

            Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Color Gray
            Write-ColorOutput "ESTIMATED TOTAL (DEV):  `$51 - `$85 per month (minimal - no APIM, Logic Apps, Data Factory)" -Color Green
            Write-ColorOutput "ESTIMATED TOTAL (DEV):  `$101 - `$135 per month (with APIM only)" -Color Yellow
            Write-ColorOutput "ESTIMATED TOTAL (DEV):  `$253 - `$290 per month (with Logic Apps, no APIM/Data Factory)" -Color Yellow
            Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Color Gray
            Write-ColorOutput ""
            Write-ColorOutput "💡 KEY COST DRIVERS:" -Color Yellow
            Write-ColorOutput "   1. Logic App Standard (~`$197/month) - LARGEST COST in Dev" -Color Red
            Write-ColorOutput "   2. API Management (~`$50/month) - Optional, Developer SKU" -Color White
            Write-ColorOutput "   3. NAT Gateway (~`$35/month) - Critical for VNet outbound traffic" -Color White
            Write-ColorOutput "   4. Function App (~`$10-30/month) - Scales with execution time" -Color White
            Write-ColorOutput "   5. Log Analytics (~`$5-15/month) - Depends on data ingestion" -Color White
            Write-ColorOutput ""
            Write-ColorOutput "💰 COST OPTIMIZATION TIPS:" -Color Cyan
            Write-ColorOutput "   • Power Platform Developer environment is FREE (use for testing)" -Color White
            Write-ColorOutput "   • Logic Apps are disabled by default - enable in tfvars only when workflows are needed" -Color White
            Write-ColorOutput "   • Data Factory is disabled by default - enable only when ETL/ELT pipelines are needed" -Color White
            Write-ColorOutput "   • Monitor Function App execution to optimize instance count" -Color White
            Write-ColorOutput "   • Adjust Log Analytics retention to control costs" -Color White
            Write-ColorOutput "   • Consider disabling APIM if not using BFF pattern (`$101/month savings)" -Color White
        }
    }

    Write-ColorOutput ""
    Write-ColorOutput "📊 COST BREAKDOWN NOTES:" -Color Cyan
    Write-ColorOutput "   • All costs are monthly estimates in USD" -Color White
    Write-ColorOutput "   • Actual costs depend on usage patterns and data transfer" -Color White
    Write-ColorOutput "   • Power Platform licensing is capacity-based (not usage-based)" -Color White
    Write-ColorOutput "   • Function App costs scale with execution time and memory" -Color White
    Write-ColorOutput "   • Log Analytics charges per GB of data ingested" -Color White
    Write-ColorOutput ""
    Write-ColorOutput "📖 DETAILED DOCUMENTATION:" -Color Cyan
    Write-ColorOutput "   See COST_ANALYSIS.md for comprehensive pricing breakdown" -Color White
    Write-ColorOutput ""
}
#endregion

# Banner
Write-ColorOutput "`n========================================" -Color Magenta
Write-ColorOutput "  Terraform Deployment Script" -Color Magenta
Write-ColorOutput "  Azure + Power Platform Infrastructure" -Color Magenta
Write-ColorOutput "========================================" -Color Magenta
Write-Info "Environment: $Environment"
Write-Info "Action: $Action"
Write-Info "Terraform Directory: $TerraformDir"
Write-ColorOutput "========================================`n" -Color Magenta

# Cost estimate-only mode
if ($Action -eq 'cost-estimate') {
    Show-CostBreakdown -Environment $Environment
    exit 0
}

# Validate prerequisites
Write-Info "Validating prerequisites..."

# Check if Terraform is installed
try {
    $terraformVersion = terraform version -json | ConvertFrom-Json
    Write-Success "Terraform version: $($terraformVersion.terraform_version)"
}
catch {
    Write-Error "Terraform is not installed or not in PATH"
    exit 1
}

# Check if Azure CLI is installed
try {
    $azVersion = az version | ConvertFrom-Json
    Write-Success "Azure CLI version: $($azVersion.'azure-cli')"
}
catch {
    Write-Warning "Azure CLI is not installed or not in PATH (required for some operations)"
}

# Check if logged in to Azure
try {
    if ($az_login_interactive) {
        az login
    }
    $azAccount = az account show 2>$null | ConvertFrom-Json
    Write-Success "Azure Account: $($azAccount.name) ($($azAccount.id))"
    Write-Info "Subscription: $($azAccount.name)"
}
catch {
    Write-Warning "Not logged in to Azure CLI. Run 'az login' if needed."
}

# Get current user's Entra ID (Azure AD) GUID for dev environment
$UserGuid = $null
if ($Environment -eq 'dev') {
    try {
        $UserGuid = az ad signed-in-user show --query id -o tsv 2>$null
        if ($UserGuid) {
            Write-Success "Current user GUID: $UserGuid"
            Write-Info "This will be used as default_power_platform_owner_id for Developer environments"
        }
    }
    catch {
        Write-Warning "Could not retrieve signed-in user GUID. Developer environments may not have an owner set."
    }
}

# Validate environment directory exists
if (-not (Test-Path $EnvironmentDir)) {
    Write-Error "Environment directory not found: $EnvironmentDir"
    exit 1
}

# Validate tfvars file exists
if (-not (Test-Path $VarFile)) {
    Write-Error "Terraform variables file not found: $VarFile"
    Write-Info "Expected location: $VarFile"
    exit 1
}

Write-Success "Prerequisites validated`n"

# Change to Terraform directory
Set-Location $TerraformDir

# Initialize Terraform if requested or if .terraform directory doesn't exist
if ($Init -or -not (Test-Path ".terraform")) {
    Write-Info "Initializing Terraform..."
    try {
        terraform init
        Write-Success "Terraform initialized successfully`n"
    }
    catch {
        Write-Error "Terraform initialization failed"
        exit 1
    }
}

# Validate Terraform configuration
if ($Action -ne 'output') {
    Write-Info "Validating Terraform configuration..."
    try {
        terraform validate
        Write-Success "Terraform configuration is valid`n"
    }
    catch {
        Write-Error "Terraform validation failed"
        exit 1
    }
}

# Show cost breakdown if requested or before apply
if ($ShowCostBreakdown -or $Action -eq 'apply') {
    Show-CostBreakdown -Environment $Environment

    if ($Action -eq 'apply' -and -not $AutoApprove) {
        Write-ColorOutput "`n⚠️  Review the cost breakdown above before proceeding." -Color Yellow
        $costConfirm = Read-Host "Do you want to continue with deployment? (yes/no)"
        if ($costConfirm -ne 'yes') {
            Write-Info "Deployment cancelled by user"
            exit 0
        }
    }
}

# Build Terraform variable arguments
$TerraformVars = @()
$TerraformVars += "-var-file=$VarFile"
if ($UserGuid -and $Environment -eq 'dev') {
    $TerraformVars += "-var=default_power_platform_owner_id=$UserGuid"
    Write-Info "Setting default Power Platform owner to current user for dev environment`n"
}

# Execute the requested action
switch ($Action) {
    'plan' {
        Write-Info "Running Terraform plan for environment: $Environment"
        Write-Info "Variables file: $VarFile`n"

        try {
            $planArgs = @('plan') + $TerraformVars + @("-out=$Environment.tfplan")
            & terraform @planArgs
            Write-Success "`nTerraform plan completed successfully"
            Write-Info "Plan saved to: $Environment.tfplan"
            Write-Info "To apply this plan, run: .\deploy.ps1 -Environment $Environment -Action apply"

            Write-ColorOutput "`n💡 TIP: Run with -ShowCostBreakdown to see detailed cost estimates" -Color Cyan
        }
        catch {
            Write-Error "Terraform plan failed"
            exit 1
        }
    }

    'apply' {
        Write-Info "Applying Terraform configuration for environment: $Environment"

        # Safety check for production
        if ($Environment -eq 'prod' -and -not $AutoApprove) {
            Write-Warning "`n⚠️  PRODUCTION DEPLOYMENT WARNING ⚠️"
            Write-Warning "You are about to deploy to PRODUCTION environment!"
            Write-Warning "Estimated monthly cost: `$1,029 - `$3,740"
            Write-ColorOutput ""
            $confirmation = Read-Host "Type 'yes' to continue"
            if ($confirmation -ne 'yes') {
                Write-Info "Apply cancelled by user"
                exit 0
            }
        }

        try {
            $applyArgs = @('apply') + $TerraformVars
            if ($AutoApprove) {
                $applyArgs += '-auto-approve'
            }
            & terraform @applyArgs
            Write-Success "`nTerraform apply completed successfully"

            # Show outputs
            Write-Info "`nResource Outputs:"
            terraform output

            Write-ColorOutput "`n✅ Deployment Summary:" -Color Green
            Write-ColorOutput "   • Environment: $Environment" -Color White
            Write-ColorOutput "   • Resources: Created successfully" -Color White
            Write-ColorOutput "   • Estimated monthly cost: See breakdown above" -Color White
            Write-ColorOutput ""
            Write-ColorOutput "📖 Next Steps:" -Color Cyan
            Write-ColorOutput "   1. Review outputs above for resource details" -Color White
            Write-ColorOutput "   2. Monitor costs in Azure Cost Management" -Color White
            Write-ColorOutput "   3. Check Application Insights for telemetry" -Color White
        }
        catch {
            Write-Error "Terraform apply failed"
            exit 1
        }
    }

    'destroy' {
        Write-Warning "`n⚠️  DESTRUCTION WARNING ⚠️"
        Write-Warning "You are about to DESTROY all resources in environment: $Environment"
        Write-ColorOutput ""

        # Safety check
        if (-not $AutoApprove) {
            $confirmation = Read-Host "Type 'destroy-$Environment' to confirm"
            if ($confirmation -ne "destroy-$Environment") {
                Write-Info "Destroy cancelled by user"
                exit 0
            }
        }

        try {
            $destroyArgs = @('destroy') + $TerraformVars
            if ($AutoApprove) {
                $destroyArgs += '-auto-approve'
            }
            & terraform @destroyArgs
            Write-Success "`nTerraform destroy completed successfully"
            Write-Info "All resources in $Environment environment have been removed"
        }
        catch {
            Write-Error "Terraform destroy failed"
            exit 1
        }
    }

    'output' {
        Write-Info "Displaying Terraform outputs for environment: $Environment`n"

        try {
            terraform output

            Write-Info "`nTo get JSON format, run: terraform output -json"
            Write-Info "To get specific output, run: terraform output <output_name>"
        }
        catch {
            Write-Error "Failed to retrieve outputs"
            exit 1
        }
    }

    'validate' {
        Write-Success "Validation completed (already performed above)`n"
    }
}

Write-ColorOutput "`n========================================" -Color Magenta
Write-Success "Script completed successfully!"
Write-ColorOutput "========================================`n" -Color Magenta
