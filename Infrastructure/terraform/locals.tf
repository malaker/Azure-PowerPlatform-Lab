# External data source to encode tenant ID as GUID bytes
# This is required for federated credentials subject pattern
data "external" "tenant_id_encoded" {
  program = ["powershell", "-Command", <<-EOT
    $tenantId = "${data.azurerm_client_config.current.tenant_id}"
    $guid = [System.Guid]::Parse($tenantId)
    $bytes = $guid.ToByteArray()
    $base64 = [System.Convert]::ToBase64String($bytes)
    $base64Url = $base64.Replace('+', '-').Replace('/', '_').TrimEnd('=')
    Write-Output "{`"encoded`":`"$base64Url`"}"
  EOT
  ]
}

# Local values for resource naming and configuration
locals {
  # Environment configuration
  environment_config = {
    dev = {
      location                    = "westeurope"
      key_vault_sku              = "standard"
      soft_delete_retention_days = 7
      enable_purge_protection    = false
      public_network_access      = true
      backup_location            = "northeurope"
    }
  }

  # Current environment configuration
  current_env_config = local.environment_config[var.environment]

  # Naming convention - Azure best practices
  # Pattern: {resource_type_prefix}-{project}-{environment}-{region_short}-{instance}
  region_short_names = {
    westeurope   = "weu"
    northeurope  = "neu"
  }

  region_short = lookup(local.region_short_names, local.current_env_config.location, "weu")

  # Base naming components
  project_short = lower(replace(var.project_name, "/[^a-zA-Z0-9]/", ""))
  env_short     = lower(var.environment)

  # Storage account naming (max 24 chars, no hyphens, lowercase alphanumeric only)
  # Use abbreviated project name to fit within constraints
  # Example: "pplab01" (7 chars) + "dev" (3) + "func" (4) + "weu" (3) = 17 chars
  project_storage_abbr = "pplab01"

  # Random suffix for globally unique resource names
  # Uses first 4 characters of random_id to keep names short
  # This ensures uniqueness when code is shared/open-sourced
  random_suffix = lower(substr(random_id.unique_suffix.hex, 0, 4))

  # Resource name patterns for globally unique resources
  # These names include a random suffix to ensure uniqueness when code is shared

  # Key Vault names must be globally unique (3-24 chars, alphanumeric and hyphens)
  # Format: {env}-{project}-kv-{region}-{random}
  # Example: dev-pplab-kv-weu-a1b2
  key_vault_name = "${local.env_short}-${substr(local.project_storage_abbr, 0, 5)}-kv-${local.region_short}-${local.random_suffix}"

  # Storage Account names must be globally unique (3-24 chars, lowercase alphanumeric only, no hyphens)
  # Format: {env}{project}{purpose}{region}{random}
  # Example: devpplab01funcweua1b2 (22 chars)
  storage_account_name_prefix = "${local.env_short}${local.project_storage_abbr}"

  # Common tags following Azure tagging best practices
  common_tags = merge(
    var.additional_tags,
    {
      Environment       = var.environment
      Project           = var.project_name
      ManagedBy         = "Terraform"
      CreatedDate       = formatdate("YYYY-MM-DD", timestamp())
      CostCenter        = var.cost_center
      Owner             = var.owner
      DataClassification = var.data_classification
    }
  )

  # Resource-specific tags
  key_vault_tags = merge(
    local.common_tags,
    {
      ResourceType = "KeyVault"
      Purpose      = "Secrets management for ${var.project_name}"
      Backup       = var.environment == "prod" ? "enabled" : "disabled"
    }
  )

  # App Registration configurations
  # Format: {environment}-{name}
  app_registration_configs = {
    for app in var.app_registrations : app.name => {
      display_name             = "${var.environment}-${app.name}"
      description              = "${app.description} - ${upper(var.environment)} environment"
      secret_expiration        = var.environment == "prod" ? "8760h" : "4380h" # 1 year for prod, 6 months for others
      sign_in_audience         = app.sign_in_audience != null ? app.sign_in_audience : "AzureADMyOrg"
      redirect_uris            = try(app.redirect_uris, [])
      required_resource_access = try(app.required_resource_access, [])
      expose_api               = try(app.expose_api, false)
      api_scope_name           = try(app.api_scope_name, "access_as_application")
      api_scope_description    = try(app.api_scope_description, "Access the API as an application")
      expose_app_roles         = try(app.expose_app_roles, false)
      app_roles                = try(app.app_roles, [])
    }
  }

  # Resource group configurations
  # Format: rg-{environment}-{name}
  resource_group_configs = {
    for rg in var.resource_groups : rg.name => {
      name     = "rg-${var.environment}-${rg.name}"
      location = rg.location != null ? rg.location : local.current_env_config.location
      tags     = merge(local.common_tags, rg.tags != null ? rg.tags : {}, {
        Purpose = rg.purpose != null ? rg.purpose : "Resource group for ${rg.name}"
      })
    }
  }

  # Power Platform environment configurations
  # Format: {environment}-{name}
  power_platform_configs = {
    for env in var.power_platform_environments : env.name => {
      display_name               = "${var.environment}-${env.name}"
      description                = "${env.description} - ${upper(var.environment)} environment"
      location                   = env.location
      environment_type           = env.environment_type
      # Use environment-specific owner_id if provided, otherwise use default for Developer environments
      owner_id                   = env.owner_id != null ? env.owner_id : (env.environment_type == "Developer" ? var.default_power_platform_owner_id : null)
      release_cycle              = env.release_cycle
      language_code              = env.language_code
      currency_code              = env.currency_code
      security_group_id          = env.security_group_id
      create_app_user            = env.create_app_user
      application_client_id      = env.app_registration != null ? module.app_registrations[env.app_registration].client_id : ""
      # Resolve additional app registration names to client IDs
      additional_application_users = [for app_name in try(env.additional_app_registrations, []) : module.app_registrations[app_name].client_id]
      security_roles             = env.security_roles
      enable_managed_environment = env.enable_managed_environment
    }
  }

  # ===================================
  # Federated Credentials for Power Platform
  # ===================================

  # Base64 URL encode tenant ID (without padding)
  # Encode tenant ID as GUID bytes (not string) to base64 URL format
  # PowerShell script converts GUID string to bytes, then to base64 URL-safe encoding
  # Example: 5e512ab3-88fb-4585-ad13-9d507e7101e1 -> sypRXvuIhUWtE51QfnEB4Q
  tenant_id_base64_url = data.external.tenant_id_encoded.result.encoded

  # Federated credential subject suffix based on mode
  # Production pattern (well-known CA signed certificates): /i/{issuer}/s/{certificateSubject}
  # Development pattern (self-signed certificates): /hash/{sha256_of_certificate}
  federated_credential_subject_suffix = (
    var.powerplatform_federated_credential_mode == "production"
    ? "/i/${var.powerplatform_federated_credential_issuer}/s/${var.powerplatform_federated_credential_certificate_subject}"
    : "/hash/${var.powerplatform_federated_credential_certificate_hash}"
  )

  # Construct federated credential subjects for each Power Platform environment
  # Base pattern: /eid1/c/pub/t/{encodedTenantId}/a/qzXoWDkuqUa3l6zM5mM0Rw/n/plugin/e/{environmentId}
  # Followed by mode-specific suffix (production: /i/{issuer}/s/{subject}, development: /hash/{sha256})
  powerplatform_federated_credentials = {
    for env_name, env in module.powerplatform : env_name => {
      display_name = "${var.environment}-${env_name}-plugin-credential"
      description  = "Federated credential for Dataverse plugin authentication in ${var.environment}-${env_name} (${var.powerplatform_federated_credential_mode} mode)"
      issuer       = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
      audiences    = ["api://AzureADTokenExchange"]
      subject      = "/eid1/c/pub/t/${local.tenant_id_base64_url}/a/qzXoWDkuqUa3l6zM5mM0Rw/n/plugin/e/${env.environment_id}${local.federated_credential_subject_suffix}"
    }
  }
}
