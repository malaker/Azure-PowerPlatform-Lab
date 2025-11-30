# ===================================
# Azure Enterprise Policy
# ===================================
#
# Enterprise policies enable advanced networking features for Power Platform:
# - Subnet delegation for VNet integration
# - Private networking capabilities
# - Enhanced security and compliance
#
# The enterprise policy is created as an Azure resource, then linked to
# Power Platform environments using powerplatform_enterprise_policy resource

# NOTE: Enterprise policies are created through Azure ARM API
# The Azure provider doesn't have a native resource for this yet,
# so we use azapi provider for ARM template deployment

resource "azapi_resource" "enterprise_policy" {
  type      = "Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview"
  name      = var.name
  location  = var.location
  parent_id = var.resource_group_id

  identity {
    type = "SystemAssigned"
  }
  body = {
    kind = "NetworkInjection"
    properties = {
      healthStatus = "Undetermined"
      networkInjection = {
        virtualNetworks = [
          for subnet in var.subnets : {
            id = regex("^(.+)/subnets/.+$", subnet.id)[0]  # Extract VNet ID from subnet ID
            subnet = {
              name = subnet.name
            }
          }
        ]
      }
    }
  }

  schema_validation_enabled = false

  tags = merge(
    var.tags,
    {
      DisplayName = var.display_name
    }
  )

  response_export_values = ["properties.systemId"]
}

# ===================================
# Power Platform Environment Linkage
# ===================================

# NOTE: The linkage between the Azure enterprise policy and Power Platform environment
# is handled separately in the power-platform module (modules/power-platform/main.tf).
#
# Workflow:
# 1. This module creates the Azure enterprise policy resource via azapi
# 2. The enterprise policy ID is passed to the power-platform module
# 3. The power-platform module creates a powerplatform_enterprise_policy resource
#    to link the environment to this Azure enterprise policy
#
# The powerplatform_enterprise_policy resource requires:
# - environment_id: The Power Platform environment to link
# - system_id: The Azure enterprise policy ID (output from this module)
# - policy_type: "NetworkInjection" for subnet delegation
