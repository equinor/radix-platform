terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "rg_group" {
  name = "clusters"
}

data "azurerm_subscription" "current" {}

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
  for_each           = toset(var.K8S_ENVIROMENTS)
  name               = each.key
  network_manager_id = azurerm_network_manager.networkmanager.id
  description        = "Network Group for ${each.key} virtual networks"
}

data "azurerm_virtual_network" "vnet-hub" {
  for_each            = toset(var.K8S_ENVIROMENTS)
  name                = "vnet-hub"
  resource_group_name = lookup(var.vnet_rg_names, "${each.key}", "")
}

resource "azurerm_network_manager_connectivity_configuration" "config" {
  for_each              = toset(var.K8S_ENVIROMENTS)
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
