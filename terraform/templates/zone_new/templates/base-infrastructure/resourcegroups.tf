

module "resourcegroup_common" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.common_resource_group
  location = module.config.location
}

module "resourcegroup_clusters" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.cluster_resource_group
  location = module.config.location
}

module "resourcegroup_vnet" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.vnet_resource_group
  location = module.config.location
}

output "az_resource_group_clusters" {
  value = module.resourcegroup_clusters.data.name
}

output "az_resource_group_common" {
  value = module.config.common_resource_group
}



