# ===================================
# Data Sources
# ===================================

# Get current public IP of the machine running Terraform (optional)
data "http" "current_ip" {
  count = var.enable_terraform_runner_ip && var.terraform_runner_ip == null ? 1 : 0
  url   = "https://api.ipify.org?format=json"

  request_headers = {
    Accept = "application/json"
  }
}

locals {
  # Use manually provided IP if available, otherwise use auto-detected IP
  current_ip = var.terraform_runner_ip != null ? var.terraform_runner_ip : (
    var.enable_terraform_runner_ip && length(data.http.current_ip) > 0 ?
    jsondecode(data.http.current_ip[0].response_body).ip : ""
  )

  # Build list of allowed IPs in CIDR format
  allowed_ips = concat(
    local.current_ip != "" ? ["${local.current_ip}/32"] : [],
    var.nat_gateway_public_ip != null ? ["${var.nat_gateway_public_ip}/32"] : [],
    var.allowed_ip_ranges
  )

  # Join IPs for API call (comma-separated)
  allowed_ips_string = join(",", local.allowed_ips)
}

# ===================================
# Power Platform Environment
# ===================================

resource "powerplatform_environment" "this" {
  display_name     = var.display_name
  location         = var.location
  environment_type = var.environment_type
  cadence          = "Moderate"
  description      = var.description

  # Owner ID - only for Developer environments
  owner_id      = var.environment_type == "Developer" ? var.owner_id : null
  release_cycle = var.release_cycle

  # Enterprise policies are linked via separate resource
  # See powerplatform_enterprise_policy resource below

  # Dataverse configuration
  # Note: Developer environments do not support security_group_id
  dataverse = {
    language_code     = var.language_code
    currency_code     = var.currency_code
    security_group_id = var.environment_type != "Developer" ? var.security_group_id : null
  }
}

# ===================================
# Enterprise Policy Assignment
# ===================================

# Wait for environment to be fully provisioned before linking enterprise policy
resource "time_sleep" "wait_for_environment" {
  count = var.enable_enterprise_policy ? 1 : 0

  create_duration = "60s"

  depends_on = [powerplatform_environment.this]
}

# Link environment to enterprise policy for subnet delegation
# NOTE: Enterprise policy must be linked immediately after environment creation.
# If this fails with "NewNetworkInjection cannot be performed", it means the environment
# already existed before this was applied. You'll need to destroy and recreate the environment.
resource "powerplatform_enterprise_policy" "this" {
  count = var.enable_enterprise_policy ? 1 : 0

  environment_id = powerplatform_environment.this.id
  system_id      = var.enterprise_policy_id
  policy_type    = "NetworkInjection"

  depends_on = [time_sleep.wait_for_environment]
}

# ===================================
# Managed Environment Configuration
# ===================================

# ISSUE: The powerplatform provider (v3.8.0 - v3.9.1) requires maker_onboarding_url
# and maker_onboarding_markdown as required fields, but the Power Platform API rejects
# these fields with error:
# "Could not find member 'makerOnboardingUrl' on object of type
# 'GovernanceConfigurationExtendedSettingsDefinition'"
#
# When manually creating managed environments through the Admin Center, these fields
# are optional and can be configured later. The provider incorrectly sends them in
# the initial API call.
#
# WORKAROUND: Using PAC CLI via null_resource instead of native Terraform resource.
# When a new provider version fixes this issue, comment out the null_resource below
# and uncomment the powerplatform_managed_environment resource.

# TODO: Monitor https://github.com/microsoft/terraform-provider-power-platform/issues
# for a fix, then switch back to native Terraform resource

# NATIVE TERRAFORM RESOURCE (Currently Broken - Uncomment when provider is fixed)
# resource "powerplatform_managed_environment" "this" {
#   count = var.enable_managed_environment ? 1 : 0
#
#   environment_id = powerplatform_environment.this.id
#
#   is_group_sharing_disabled   = var.managed_env_is_group_sharing_disabled
#   is_usage_insights_disabled  = var.managed_env_is_usage_insights_disabled
#   limit_sharing_mode          = var.managed_env_limit_sharing_mode
#   max_limit_user_sharing      = var.managed_env_max_limit_user_sharing
#   solution_checker_mode       = var.managed_env_solution_checker_mode
#   suppress_validation_emails  = var.managed_env_suppress_validation_emails
#   maker_onboarding_markdown   = var.managed_env_maker_onboarding_markdown
#   maker_onboarding_url        = var.managed_env_maker_onboarding_url
#
#   depends_on = [powerplatform_environment.this]
# }

# WORKAROUND: PAC CLI via null_resource (Currently Active)
resource "null_resource" "managed_environment" {
  count = var.enable_managed_environment ? 1 : 0

  # Trigger recreation if environment ID changes
  triggers = {
    environment_id = powerplatform_environment.this.id
  }

  # Enable managed environment using Power Platform CLI
  provisioner "local-exec" {
    command = <<-EOT
      pac admin set-governance-config `
        --environment ${powerplatform_environment.this.id} `
        --protection-level Standard `
        ${var.managed_env_is_group_sharing_disabled ? "--disable-group-sharing" : ""} `
        ${var.managed_env_is_usage_insights_disabled ? "--exclude-environment-from-analysis-in-weekly-digest" : ""} `
        --limit-sharing-mode ${var.managed_env_limit_sharing_mode} `
        --max-limit-user-sharing ${var.managed_env_max_limit_user_sharing}
    EOT

    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [powerplatform_environment.this]
}

# ===================================
# Application User (Service Principal)
# ===================================

# Add the app registration as an application admin in the environment
resource "powerplatform_environment_application_admin" "app_user" {
  count = var.create_application_user ? 1 : 0

  environment_id = powerplatform_environment.this.id
  application_id = var.application_client_id

  depends_on = [powerplatform_environment.this]
}

# Add additional application users to the environment
resource "powerplatform_environment_application_admin" "additional_app_users" {
  for_each = { for idx, client_id in var.additional_application_users : idx => client_id }

  environment_id = powerplatform_environment.this.id
  application_id = each.value

  depends_on = [powerplatform_environment.this]
}

# ===================================
# Security Role Assignments
# ===================================

# NOTE: The powerplatform_environment_application_admin resource automatically
# assigns the System Administrator role to the application user.
# Additional security roles (Service Reader, Service Writer, etc.) are not currently
# supported by the Terraform provider and would need to be assigned manually through:
# - Power Platform Admin Center
# - Power Platform CLI (pac admin assign-user)
# - Power Platform API
#
# For more information, see:
# https://registry.terraform.io/providers/microsoft/power-platform/latest/docs/resources/environment_application_admin

# ===================================
# Environment Settings (IP Firewall)
# ===================================

resource "powerplatform_environment_settings" "this" {
  # IP firewall requires Managed Environment, so only create if both are enabled
  count = var.enable_managed_environment && var.enable_ip_firewall ? 1 : 0

  environment_id = powerplatform_environment.this.id

  product = {
    security = {
      enable_ip_based_firewall_rule               = true
      enable_ip_based_firewall_rule_in_audit_mode = var.ip_firewall_audit_mode
      allowed_ip_range_for_firewall               = toset(local.allowed_ips)
      allow_application_user_access               = var.ip_firewall_allow_application_users
      allow_microsoft_trusted_service_tags        = var.ip_firewall_allow_microsoft_services
      allowed_service_tags_for_firewall           = var.ip_firewall_allowed_service_tags != null ? toset(var.ip_firewall_allowed_service_tags) : null
      reverse_proxy_ip_addresses                  = var.ip_firewall_reverse_proxy_ips != null ? toset(var.ip_firewall_reverse_proxy_ips) : null
    }
  }

  # Explicit dependency on Managed Environment (required for IP firewall)
  # NOTE: If switching back to powerplatform_managed_environment resource,
  # update this dependency to: powerplatform_managed_environment.this
  depends_on = [
    null_resource.managed_environment,  # Currently using CLI workaround
    # powerplatform_managed_environment.this,  # Uncomment when provider is fixed
    powerplatform_environment.this
  ]
}

# ===================================
# Solution Package Packing during terraform apply
# ===================================

# Pack solution with token replacement for app registration client ID
# This resource prepares the solution before import by:
# 1. src_template that contains solution files with tokens (REPLACE_MANAGEDIDENTITY and REPLACE_TENANTID) to be replaced with valid values
# 2. Replacing {REPLACE_MANAGEDIDENTITYID} tokens with the app registration client ID
# 3. Replacing {REPLACE_TENANTID} tokens with the tenant ID
# 4. Packing the solution folder into a ZIP file
resource "null_resource" "integration_guide_solution" {
  count = var.solution_folder != "" ? 1 : 0

  # Trigger repacking when variables change
  triggers = {
    solution_folder      = var.solution_folder
    managed_identity_id  = var.managed_identity_id
    tenant_id            = var.tenant_id
    output_zip           = var.solution_pack_zip_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Use literal paths with \\?\ prefix for long path support in PowerShell
      $ErrorActionPreference = "Stop"

      # Resolve paths to absolute paths (handles relative paths correctly)
      $solutionFolderRaw = "${var.solution_folder}"
      $outputZipRaw = "${var.solution_pack_zip_path}"

      # Convert to absolute paths
      if ([System.IO.Path]::IsPathRooted($solutionFolderRaw)) {
        $solutionFolder = $solutionFolderRaw
      } else {
        $solutionFolder = Resolve-Path -Path $solutionFolderRaw -ErrorAction Stop | Select-Object -ExpandProperty Path
      }

      #copy template solution file to actual solution src folder to inject tenantid and managedidentity id
      Copy-Item "$solutionFolder\..\src_template\*" -Destination "${var.solution_folder}" -Recurse

      if ([System.IO.Path]::IsPathRooted($outputZipRaw)) {
        $outputZip = $outputZipRaw
      } else {
        $outputZipParent = Split-Path $outputZipRaw -Parent
        $outputZipName = Split-Path $outputZipRaw -Leaf
        if (Test-Path $outputZipParent) {
          $outputZipParentResolved = Resolve-Path -Path $outputZipParent | Select-Object -ExpandProperty Path
        } else {
          # Create the directory if it doesn't exist and get its absolute path
          New-Item -ItemType Directory -Path $outputZipParent -Force | Out-Null
          $outputZipParentResolved = Resolve-Path -Path $outputZipParent | Select-Object -ExpandProperty Path
        }
        $outputZip = Join-Path $outputZipParentResolved $outputZipName
      }

      Write-Host "Using absolute paths:"
      Write-Host "  Solution folder: $solutionFolder"
      Write-Host "  Output ZIP: $outputZip"

      # Replace tokens in Customizations.xml
      $customizationXmlPath = Join-Path $solutionFolder "Other\Customizations.xml"
      Write-Host "Processing Customizations.xml at: $customizationXmlPath"
      if (-not (Test-Path -LiteralPath $customizationXmlPath)) {
        throw "Customizations.xml not found at: $customizationXmlPath"
      }
      $customizationXml = Get-Content -LiteralPath $customizationXmlPath -Raw
      $customizationXml = $customizationXml -replace "{REPLACE_MANAGEDIDENTITYID}", "${var.managed_identity_id}"
      $customizationXml = $customizationXml -replace "{REPLACE_TENANTID}", "${var.tenant_id}"
      Set-Content -LiteralPath $customizationXmlPath -Value $customizationXml -Force

      # Replace tokens in pluginpackage.xml (search recursively as it can be in different locations)
      Write-Host "Searching for pluginpackage.xml files..."
      $pluginPackageFiles = Get-ChildItem -LiteralPath $solutionFolder -Filter "pluginpackage.xml" -Recurse -ErrorAction SilentlyContinue
      Write-Host "Found $($pluginPackageFiles.Count) pluginpackage.xml file(s)"
      foreach ($pluginPackageFile in $pluginPackageFiles) {
        Write-Host "Processing pluginpackage.xml at: $($pluginPackageFile.FullName)"
        $pluginPackageXml = Get-Content -LiteralPath $pluginPackageFile.FullName -Raw
        $pluginPackageXml = $pluginPackageXml -replace "{REPLACE_MANAGEDIDENTITYID}", "${var.managed_identity_id}"
        Set-Content -LiteralPath $pluginPackageFile.FullName -Value $pluginPackageXml -Force
      }

      # Ensure output directory exists
      $outputDir = Split-Path $outputZip -Parent
      if (-not (Test-Path -LiteralPath $outputDir)) {
        Write-Host "Creating output directory: $outputDir"
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
      }

      # Pack solution
      Write-Host "Packing solution..."
      Write-Host "  Source folder: $solutionFolder"
      Write-Host "  Output ZIP: $outputZip"
      pac solution pack --folder "$solutionFolder" --zipfile "$outputZip" --packagetype unmanaged

      if ($LASTEXITCODE -ne 0) {
        throw "pac solution pack failed with exit code: $LASTEXITCODE"
      }
      Write-Host "Solution packed successfully!"
    EOT

    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [powerplatform_environment.this]
}

# Import Power Platform solutions into the environment
# Terraform scripts only prepares solution package in order to automate injection of tenant id and managed identity configuration.
# It is advised to import solution seperately e.g using pac cli/maker portal/XrmToolbox.
