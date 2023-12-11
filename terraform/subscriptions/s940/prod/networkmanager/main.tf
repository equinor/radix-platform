
data "azurerm_subscription" "current" {}

# resource "azurerm_network_manager" "networkmanager" {
#   name                = "${local.external_outputs.common.shared.AZ_SUBSCRIPTION_SHORTNAME}-ANVM"
#   location            = local.external_outputs.common.shared.location
#   resource_group_name = local.external_outputs.clusters.outputs.clusters.resource_group
#   scope_accesses      = ["Connectivity"]
#   description         = "${local.external_outputs.common.shared.AZ_SUBSCRIPTION_SHORTNAME}-Azure Network Mananger - ${local.external_outputs.clusters.outputs.clusters.location}"

#   scope {
#     subscription_ids = [data.azurerm_subscription.current.id]
#   }
# }

module "azurerm_network_manager" {
  source                 = "../../../modules/azurerm/networkmanager"
  subscription_shortname = local.external_outputs.common.shared.subscription_shortname
  location               = local.external_outputs.common.shared.location
  resource_group         = local.external_outputs.clusters.outputs.clusters.resource_group
  subscription           = data.azurerm_subscription.current.id
}

resource "azurerm_network_manager_network_group" "group" {
  name               = local.external_outputs.clusters.outputs.clusters.enviroment
  network_manager_id = local.external_outputs.networkmanager.outputs.networkmanager_id
  description        = "Network Group for ${local.external_outputs.clusters.outputs.clusters.enviroment} virtual networks"
}

resource "azurerm_network_manager_connectivity_configuration" "config" {
  name                  = "Hub-and-Spoke-${local.external_outputs.clusters.outputs.clusters.enviroment}"
  description           = "Hub-and-Spoke config"
  network_manager_id    = local.external_outputs.networkmanager.outputs.networkmanager_id
  connectivity_topology = "HubAndSpoke"

  applies_to_group {
    group_connectivity = "None"
    network_group_id   = azurerm_network_manager_network_group.group.id
  }

  hub {
    resource_id   = local.external_outputs.virtualnetwork.outputs.vnethub_id
    resource_type = "Microsoft.Network/virtualNetworks"
  }
}

resource "azurerm_policy_definition" "policy" {
  name         = "Kubernetes-vnets-in-${local.external_outputs.clusters.outputs.clusters.enviroment}"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "Kubernetes vnets in ${local.external_outputs.clusters.outputs.clusters.enviroment}"

  metadata = <<METADATA
    {
    "category": "Azure Virtual Network Manager"
    }

METADATA

  policy_rule = <<POLICY_RULE
  {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Network/virtualNetworks"
        },
        {
          "allOf": [
            {
              "value": "[resourceGroup().Name]",
              "contains": "${local.external_outputs.clusters.outputs.clusters.resource_group}"
            },
            {
              "field": "location",
              "contains": "${local.external_outputs.clusters.outputs.clusters.location}"
            },
            {
              "field": "Name",
              "notcontains": "${local.policy_notcontains_name}"
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "addToNetworkGroup",
      "details": {
        "networkGroupId": "/subscriptions/${local.external_outputs.common.shared.subscription_id}/resourceGroups/clusters/providers/Microsoft.Network/networkManagers/${local.external_outputs.common.shared.AZ_SUBSCRIPTION_SHORTNAME}-ANVM/networkGroups/${local.external_outputs.clusters.outputs.clusters.enviroment}"
      }
    }
  }
  POLICY_RULE
}

resource "azurerm_subscription_policy_assignment" "assignment" {
  display_name         = "Kubernetes-vnets-in-${local.external_outputs.clusters.outputs.clusters.enviroment}"
  name                 = "341aa001461645dabaad95f0"
  location             = "eastus"
  policy_definition_id = azurerm_policy_definition.policy.id
  subscription_id      = data.azurerm_subscription.current.id
  parameters           = jsonencode({})
  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }

}
