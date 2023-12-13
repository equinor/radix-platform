resource "azurerm_network_manager" "networkmanager" {
  name                = "${var.subscription_shortname}-ANVM"
  location            = var.location
  resource_group_name = var.resource_group
  scope_accesses      = ["Connectivity"]
  description         = "${var.subscription_shortname}-Azure Network Mananger - ${var.location}"

  scope {
    subscription_ids = [var.subscription]
  }
}


# resource "azurerm_network_manager_network_group" "group" {
#   name               = var.enviroment
#   network_manager_id = var.network_manager_id
#   description        = "Network Group for ${var.enviroment} virtual networks"
# }

# resource "azurerm_network_manager_connectivity_configuration" "config" {
#   name                  = "Hub-and-Spoke-${var.enviroment}"
#   description           = "Hub-and-Spoke config"
#   network_manager_id    = var.network_manager_id
#   connectivity_topology = "HubAndSpoke"

#   applies_to_group {
#     group_connectivity = "None"
#     network_group_id   = azurerm_network_manager_network_group.group.id
#   }

#   hub {
#     resource_id   = var.vnethub_id
#     resource_type = "Microsoft.Network/virtualNetworks"
#   }
# }
