# ===================================
# Provider Configuration
# ===================================

provider "azurerm" {
  # AzureRM v4 requires explicit subscription_id when using certain auth methods
  # This will use the default subscription from Azure CLI context
  subscription_id = var.subscription_id

  features {
    key_vault {
      # Purge Key Vaults on destroy for non-prod environments (faster deletion)
      purge_soft_delete_on_destroy = var.environment != "prod"

      # Purge Key Vault keys, secrets, and certificates on destroy for non-prod (faster deletion)
      purge_soft_deleted_keys_on_destroy         = var.environment != "prod"
      purge_soft_deleted_secrets_on_destroy      = var.environment != "prod"
      purge_soft_deleted_certificates_on_destroy = var.environment != "prod"

      # Recover soft-deleted Key Vaults on create if they exist
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = var.environment == "prod"
    }

    virtual_machine {
      delete_os_disk_on_deletion     = var.environment != "prod"
      skip_shutdown_and_force_delete = false
    }
  }

  # Optional: Configure default tags for all resources
  # Uncomment if you want to enforce tags at provider level
  # default_tags {
  #   tags = {
  #     ManagedBy = "Terraform"
  #     Project   = var.project_name
  #   }
  # }
}

provider "azuread" {
  # Azure AD provider configuration
}

provider "azapi" {
  # Azure API provider for ARM template deployments
  # Used for resources not yet available in the azurerm provider
  subscription_id = var.subscription_id
}

provider "powerplatform" {
  # Power Platform provider configuration
  # Uses service principal authentication from app registration
  use_cli = true
}

provider "random" {
  # Random provider for generating unique values
}

provider "time" {
  # Time provider for time-based resources
}