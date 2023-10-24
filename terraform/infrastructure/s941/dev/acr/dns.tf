locals {
  clusterEnvironment = {
    for cluster in data.azurerm_kubernetes_cluster.k8s : cluster.name =>
    startswith( lower(cluster.name), "weekly-" ) ? "dev" :
    startswith(lower( cluster.name), "playground-") ? "playground" :
    startswith(lower( cluster.name), "eu-") ? "prod" :
    startswith(lower( cluster.name), "c2-") ? "c2" : "unknown"
  }
}
output "clusters" {
  value = local.clusterEnvironment
}
data "azurerm_virtual_network" "k8s" {
  for_each = data.azurerm_kubernetes_cluster.k8s

  name                = "vnet-${each.value.name}"
  resource_group_name = var.AZ_RESOURCE_GROUP_CLUSTERS
}


# Create Private DNS Zone

resource "azurerm_private_dns_zone" "zone" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                = "privatelink.azurecr.io"
  resource_group_name = var.virtual_networks[each.value].rg_name
}


# Link DNS Zone to Cluster

data "azurerm_virtual_network" "vnet" {
  for_each = data.azurerm_kubernetes_cluster.k8s

  name                = "vnet-${each.value.name}"
  resource_group_name = var.AZ_RESOURCE_GROUP_CLUSTERS
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  for_each = data.azurerm_virtual_network.vnet

  name                  = each.key # Cluster Name
  private_dns_zone_name = "privatelink.azurecr.io"
  resource_group_name   = var.virtual_networks[local.clusterEnvironment[each.key]].rg_name
  virtual_network_id    = each.value.id
}
