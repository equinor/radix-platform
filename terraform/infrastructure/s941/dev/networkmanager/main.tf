terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}

data "azurerm_resource_group" "rg_group" {
  name = "clusters"
}

data "azurerm_subscription" "current" {
  subscription_id = var.AZ_SUBSCRIPTION_ID
}

resource "azurerm_network_manager" "networkmanager" {
  name                = "${var.AZ_SUBSCRIPTION_SHORTNAME}-ANVM"
  location            = data.azurerm_resource_group.rg_group.location
  resource_group_name = data.azurerm_resource_group.rg_group.name
  scope_accesses      = ["Connectivity"]
  description         = "${var.AZ_SUBSCRIPTION_SHORTNAME}-Azure Network Mananger - northeurope"

  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }
}

resource "azurerm_network_manager_network_group" "group" {
  for_each           = var.K8S_ENVIROMENTS
  name               = each.key
  network_manager_id = azurerm_network_manager.networkmanager.id
  description        = "Network Group for ${each.key} virtual networks"
}

data "azurerm_virtual_network" "vnet-hub" {
  for_each            = var.K8S_ENVIROMENTS
  name                = "vnet-hub"
  resource_group_name = lookup(var.vnet_rg_names, "${each.key}", "")
}

resource "azurerm_network_manager_connectivity_configuration" "config" {
  for_each              = var.K8S_ENVIROMENTS
  name                  = "Hub-and-Spoke-${each.key}"
  description           = "Hub-and-Spoke config"
  network_manager_id    = azurerm_network_manager.networkmanager.id
  connectivity_topology = "HubAndSpoke"

  applies_to_group {
    group_connectivity = "None"
    network_group_id   = azurerm_network_manager_network_group.group[each.key].id
  }

  hub {
    resource_id   = data.azurerm_virtual_network.vnet-hub[each.key].id
    resource_type = "Microsoft.Network/virtualNetworks"
  }
}

resource "azurerm_policy_definition" "policy" {
  depends_on   = [azurerm_network_manager.networkmanager]
  for_each     = var.K8S_ENVIROMENTS
  name         = "Kubernetes-vnets-in-${each.key}"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "Kubernetes vnets in ${each.key}"

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
              "contains": "${lookup(var.cluster_rg, "${each.key}", "")}"
            },
            {
              "field": "location",
              "contains": "${lookup(var.cluster_location, "${each.key}", "")}"
            },
            {
              "field": "Name",
              "${lookup(var.enviroment_condition, "${each.key}", "")}": "playground"
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "addToNetworkGroup",
      "details": {
        "networkGroupId": "/subscriptions/${var.AZ_SUBSCRIPTION_ID}/resourceGroups/clusters/providers/Microsoft.Network/networkManagers/${var.AZ_SUBSCRIPTION_SHORTNAME}-ANVM/networkGroups/${each.key}"
      }
    }
  }
  POLICY_RULE
}

resource "azurerm_subscription_policy_assignment" "assign_vnets_in_zone_policy" {
  depends_on           = [azurerm_policy_definition.policy]
  for_each             = azurerm_network_manager_network_group.group
  name                 = azurerm_policy_definition.policy[each.key].name
  policy_definition_id = azurerm_policy_definition.policy[each.key].id
  subscription_id      = data.azurerm_subscription.current.id
}

resource "azurerm_network_manager_deployment" "connectivity_topology" {
  for_each           = var.K8S_ENVIROMENTS
  network_manager_id = azurerm_network_manager.networkmanager.id
  location           = var.AZ_LOCATION
  scope_access       = "Connectivity"
  configuration_ids  = [azurerm_network_manager_connectivity_configuration.config[each.key].id]
}