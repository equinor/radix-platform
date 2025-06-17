data "azurerm_subscription" "current" {}

module "config" {
  source = "../../../modules/config"
}

module "radix_base" {
  source                  = "../../../modules/radix_base"
  cluster_resource_group  = module.config.cluster_resource_group
  cluster_type            = module.config.cluster_type
  common_resource_group   = module.config.common_resource_group
  environment             = module.config.environment
  key_vault_name          = module.config.key_vault_name
  location                = module.config.location
  private_dns_zones_names = module.config.private_dns_zones_names
  secondary_location      = module.config.secondary_location
  storageaccounts         = var.storageaccounts
  subscription_shortname  = module.config.subscription_shortname
  testzone                = module.config.testzone
  vnet_resource_group     = module.config.vnet_resource_group
  radix_cr_cicd           = var.radix_cr_cicd
}