module "cluster_network" {
  for_each            = module.clusters.nsg
  source              = "../../../modules/cluster_network"
  resource_group_name = module.config.cluster_resource_group
  location            = module.config.location
  cluster_name        = each.key
}

# output "nsg" {
#   value = module.clusters.nsg
# }

