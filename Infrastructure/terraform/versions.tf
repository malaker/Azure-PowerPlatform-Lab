terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.21"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = ">=3.9.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    null = {
      source = "hashicorp/null"
    }
  }

  # Backend configuration - uncomment and configure for remote state
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate<unique>"
  #   container_name       = "tfstate"
  #   key                  = "powerplatform.tfstate"
  # }
}

