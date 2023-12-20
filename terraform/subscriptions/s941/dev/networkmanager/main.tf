
data "azurerm_subscription" "current" {}

module "azurerm_network_manager" {
  source                 = "../../../modules/networkmanager"
  subscription_shortname = local.external_outputs.global.data.subscription_shortname
  location               = local.external_outputs.common.data.location
  resource_group         = local.external_outputs.clusters.data.resource_group
  subscription           = data.azurerm_subscription.current.id
}

module "azurerm_network_manager_network_group" {
  source             = "../../../modules/networkmanager_networkgroup"
  enviroment         = local.external_outputs.clusters.data.enviroment
  network_manager_id = module.azurerm_network_manager.data.id
}

module "azurerm_network_manager_connectivity_configuration" {
  source             = "../../../modules/networkmanager_connectivity"
  enviroment         = local.external_outputs.clusters.data.enviroment
  network_manager_id = local.external_outputs.networkmanager.data.id
  network_group_id   = module.azurerm_network_manager_network_group.data.id
  vnethub_id         = local.external_outputs.virtualnetwork.data.id
}


resource "azurerm_policy_definition" "policy" {
  name         = "Kubernetes-vnets-in-${local.external_outputs.clusters.data.enviroment}"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "Kubernetes vnets in ${local.external_outputs.clusters.data.enviroment}"

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
              "contains": "${local.external_outputs.clusters.data.resource_group}"
            },
            {
              "field": "location",
              "contains": "${local.external_outputs.clusters.data.location}"
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
        "networkGroupId": "/subscriptions/${local.external_outputs.global.data.subscription_id}/resourceGroups/clusters/providers/Microsoft.Network/networkManagers/${local.external_outputs.global.data.subscription_shortname}-ANVM/networkGroups/${local.external_outputs.clusters.data.enviroment}"
      }
    }
  }
  POLICY_RULE
}

module "azurerm_subscription_policy_assignment" {
  source       = "../../../modules/policyassignment"
  enviroment   = local.external_outputs.clusters.data.enviroment
  location     = local.external_outputs.common.data.location
  policy_id    = azurerm_policy_definition.policy.id
  subscription = data.azurerm_subscription.current.id
}
