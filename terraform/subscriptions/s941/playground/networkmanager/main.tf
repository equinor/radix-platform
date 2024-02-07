
data "azurerm_subscription" "current" {}

module "azurerm_network_manager_network_group" {
  source             = "../../../modules/networkmanager_networkgroup"
  enviroment         = local.external_outputs.common.data.enviroment_S
  network_manager_id = local.external_outputs.networkmanager.data.id
}

module "azurerm_network_manager_connectivity_configuration" {
  source             = "../../../modules/networkmanager_connectivity"
  enviroment         = local.external_outputs.common.data.enviroment_S
  network_manager_id = local.external_outputs.networkmanager.data.id
  network_group_id   = module.azurerm_network_manager_network_group.data.id
  vnethub_id         = local.external_outputs.virtualnetwork.data.vnet_hub.id
}

resource "azurerm_policy_definition" "policy" {
  name         = "Kubernetes-vnets-in-${local.external_outputs.common.data.enviroment_S}"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "Kubernetes vnets in ${local.external_outputs.common.data.enviroment_S}"

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
              "contains": "${local.external_outputs.common.data.enviroment_L}"
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "addToNetworkGroup",
      "details": {
        "networkGroupId": "/subscriptions/${local.external_outputs.global.data.subscription_id}/resourceGroups/clusters/providers/Microsoft.Network/networkManagers/${local.external_outputs.global.data.subscription_shortname}-ANVM/networkGroups/${local.external_outputs.common.data.enviroment_S}"
      }
    }
  }
  POLICY_RULE
}

# module "azurerm_subscription_policy_assignment" {
#   source       = "../../../modules/policyassignment"
#   enviroment   = local.external_outputs.common.data.enviroment_S
#   location     = local.external_outputs.common.data.location
#   policy_id    = azurerm_policy_definition.policy.id
#   subscription = data.azurerm_subscription.current.id
# }

# module "network_publicipprefix" {
#   for_each            = local.flattened_publicipprefix
#   source              = "../../../modules/network_publicipprefix"
#   publicipprefixname  = "ippre-${each.key}-aks-${local.external_outputs.common.data.enviroment_L}-${local.external_outputs.common.data.location}-001"
#   location            = local.external_outputs.common.data.location
#   resource_group_name = local.external_outputs.common.data.resource_group
#   zones               = each.value.zones
# }
