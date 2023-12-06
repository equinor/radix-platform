terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}

resource "azurerm_policy_definition" "policy" {
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
