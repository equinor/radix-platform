resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${var.clustername}-link"
  resource_group_name   = var.cluster_vnet_resourcegroup
  private_dns_zone_name = var.private_dns_zone
  virtual_network_id    = var.vnet_cluster_hub_id
}