module "config" {
  source = "../../../modules/config"
}


data "azurerm_virtual_network" "this" {
  name                = "vnet-hub"
  resource_group_name = "cluster-vnet-hub-prod"
}

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
  source                 = "../../../modules/networkmanager"
  subscription_shortname = "s940"
  location               = module.config.location
  resource_group         = "clusters"
  subscription           = module.config.subscription
}

module "azurerm_network_manager_network_group" {
  source             = "../../../modules/networkmanager_networkgroup"
  enviroment         = "prod"
  network_manager_id = module.azurerm_network_manager.data.id
}

module "azurerm_network_manager_connectivity_configuration" {
  source             = "../../../modules/networkmanager_connectivity"
  enviroment         = "prod"
  network_manager_id = module.azurerm_network_manager.data.id
  network_group_id   = module.azurerm_network_manager_network_group.data.id
  vnethub_id         = data.azurerm_virtual_network.this.id
}

resource "azurerm_policy_definition" "policy" {
  name         = "Kubernetes-vnets-in-prod"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "Kubernetes vnets in prod"

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
              "contains": "clusters"
            },
            {
              "field": "location",
              "contains": "${module.config.location}"
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "addToNetworkGroup",
      "details": {
        "networkGroupId": "/subscriptions/${module.config.subscription}/resourceGroups/clusters/providers/Microsoft.Network/networkManagers/S940-ANVM/networkGroups/prod"
      }
    }
  }
  POLICY_RULE
}

module "azurerm_subscription_policy_assignment" {
  source       = "../../../modules/policyassignment"
  enviroment   = "prod"
  location     = module.config.location
  policy_id    = azurerm_policy_definition.policy.id
  subscription = module.config.subscription
}