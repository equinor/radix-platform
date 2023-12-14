resource "azurerm_network_manager_network_group" "group" {
  name               = var.enviroment
  network_manager_id = var.network_manager_id
  description        = "Network Group for ${var.enviroment} virtual networks"
}