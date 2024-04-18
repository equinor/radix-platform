locals {
  cluster_dns = flatten([
    for key, resource in module.clusters.oidc_issuer_url : [
      for dns_zone in module.config.private_dns_zones_names :
      {
        cluster : key,
        private_dns_zone : dns_zone
      }
    ]
  ])
}

data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = module.config.vnet_resource_group
}

data "azurerm_virtual_network" "cluster" {
  for_each            = module.clusters.oidc_issuer_url
  resource_group_name = module.config.cluster_resource_group
  name                = "vnet-${each.key}"
}

module "vnet_peering" {
  source                      = "../../../modules/vnet-peering"
  for_each                    = module.clusters.oidc_issuer_url
  hub_to_cluster_peering_name = "ANM_22740FFA83EB4B03043CC7E_vnet-hub_vnet-${each.key}_1877009340"
  cluster_to_hub_peering_name = "ANM_22740FFA83EB4B03043CC7E_vnet-${each.key}_vnet-hub_1877009340"
  cluster_resource_group      = module.config.cluster_resource_group
  vnet_cluster_name           = data.azurerm_virtual_network.cluster[each.key].name
  vnet_cluster_id             = data.azurerm_virtual_network.cluster[each.key].id
  vnet_hub_id                 = data.azurerm_virtual_network.hub.id
  vnet_hub_resource_group     = module.config.vnet_resource_group
  vnet_hub_name               = data.azurerm_virtual_network.hub.name
}

module "private_dns_zone_virtual_network_peering" {
  source                     = "../../../modules/privatednszone_peering"
  for_each                   = { for key in local.cluster_dns : "${key.cluster}-${key.private_dns_zone}" => key }
  clustername                = each.value.cluster
  cluster_vnet_resourcegroup = data.azurerm_virtual_network.hub.resource_group_name
  vnet_cluster_hub_id        = data.azurerm_virtual_network.cluster[each.value.cluster].id
  private_dns_zone           = each.value.private_dns_zone
}
