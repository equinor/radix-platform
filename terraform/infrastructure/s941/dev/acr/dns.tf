resource "azurerm_private_dns_zone" "zone" {
  for_each = var.K8S_ENVIROMENTS

  name                = "privatelink.azurecr.io"
  resource_group_name = var.virtual_networks[each.key].rg_name
}


# Link DNS Zone to Cluster

data "azurerm_virtual_network" "vnet" {
  for_each = data.azurerm_kubernetes_cluster.k8s

  name                = "vnet-${each.value.name}"
  resource_group_name = data.azurerm_kubernetes_cluster.k8s[each.key].resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  for_each = data.azurerm_virtual_network.vnet

  name                  = "${each.key}-link" # Cluster Name
  private_dns_zone_name = "privatelink.azurecr.io"
  resource_group_name   = var.virtual_networks[local.clusterEnvironment[each.key]].rg_name
  virtual_network_id    = each.value.id

  depends_on = [azurerm_container_registry.app]
}
