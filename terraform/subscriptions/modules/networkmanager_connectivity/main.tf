resource "azurerm_network_manager_connectivity_configuration" "config" {
  name                  = "Hub-and-Spoke-${var.enviroment}"
  description           = "Hub-and-Spoke config"
  network_manager_id    = var.network_manager_id
  connectivity_topology = "HubAndSpoke"

  applies_to_group {
    group_connectivity = "None"
    network_group_id   = var.network_group_id
  }

  hub {
    resource_id   = var.vnethub_id
    resource_type = "Microsoft.Network/virtualNetworks"
  }
}