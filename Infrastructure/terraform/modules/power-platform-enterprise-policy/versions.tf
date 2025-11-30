terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = ">=3.9.1"
    }
  }
}
