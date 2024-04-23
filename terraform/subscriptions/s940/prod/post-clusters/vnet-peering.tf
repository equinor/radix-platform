locals {
  vnet_dns = flatten([
    for key, resource in module.clusters.vnets_url : [
      for dns_zone in module.config.private_dns_zones_names :
      {
        vnet : key,
        private_dns_zone : dns_zone
      }
    ]
  ])
}

data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = module.config.vnet_resource_group
}

data "azurerm_virtual_network" "vnets" {
  for_each            = module.clusters.vnets_url
  resource_group_name = "clusters" #TODO
  name                = each.key
}

module "vnet_peering" {
  source                      = "../../../modules/vnet-peering"
  for_each                    = module.clusters.vnets_url
  hub_to_cluster_peering_name = "ANM_22740FFA83EB4B03043CC7E_vnet-hub_vnet-eu-18_3520520940"
  cluster_to_hub_peering_name = "ANM_22740FFA83EB4B03043CC7E_vnet-eu-18_vnet-hub_3520520940"
  cluster_vnet_resource_group = "clusters" #TODO
  vnet_cluster_name           = data.azurerm_virtual_network.vnets[each.key].name
  vnet_cluster_id             = data.azurerm_virtual_network.vnets[each.key].id
  vnet_hub_id                 = data.azurerm_virtual_network.hub.id
  vnet_hub_resource_group     = module.config.vnet_resource_group
  vnet_hub_name               = data.azurerm_virtual_network.hub.name
}

module "private_dns_zone_virtual_network_peering" {
  source                     = "../../../modules/privatednszone_peering"
  for_each                   = { for key in local.vnet_dns : "${replace(key.vnet, "vnet-", "")}-${key.private_dns_zone}" => key }
  clustervnet                = "${replace(each.value.vnet, "vnet-", "")}-link"
  cluster_vnet_resourcegroup = data.azurerm_virtual_network.hub.resource_group_name
  vnet_cluster_hub_id        = data.azurerm_virtual_network.vnets[each.value.vnet].id
  private_dns_zone           = each.value.private_dns_zone
}

