terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

variable "cluster_location" {
  type = map

  default = {
    prod = "northeurope"
    c2 = "westeurope"
  }
}

variable "cluster_rg" {
  type = map

  default = {
    prod = "clusters"
    c2 = "clusters-westeurope"
  }
}

variable "enviroment_condition" {
  type = map

  default = {
    prod = "notcontains"
    c2 = "contains"
  }
}

resource "azurerm_policy_definition" "policy" {
  for_each     = toset(var.K8S_ENVIROMENTS)
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
              "${lookup(var.enviroment_condition, "${each.key}", "")}": "c2"
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

##TO DO:
#Make config for resource "azurerm_resource_policy_assignment"
