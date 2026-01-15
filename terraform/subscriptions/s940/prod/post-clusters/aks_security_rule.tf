
module "nsg_rules" {
  source              = "../../../modules/aks/nsg_rule"
  nsg_ids             = module.clusters.nsg
  resource_group_name = "clusters"
  clusters            = module.config.cluster
  networksets         = module.config.networksets
}