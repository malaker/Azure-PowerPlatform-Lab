terraform {
  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = ">=3.9.1" # Requires >= 3.4.0 for IP firewall settings in environment_settings
    }
  }
}
