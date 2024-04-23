resource "azurerm_virtual_network_peering" "hub_to_cluster" {
  name                      = var.hub_to_cluster_peering_name
  resource_group_name       = var.vnet_hub_resource_group
  virtual_network_name      = var.vnet_hub_name
  remote_virtual_network_id = var.vnet_cluster_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "cluster_to_hub" {
  name                      = var.cluster_to_hub_peering_name
  resource_group_name       = var.cluster_vnet_resource_group
  virtual_network_name      = var.vnet_cluster_name
  remote_virtual_network_id = var.vnet_hub_id
  allow_forwarded_traffic   = true
}
