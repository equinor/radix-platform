module "keyvault" {
  source              = "../../../modules/key-vault"
  location            = module.config.location
  vault_name          = "radix-keyv-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  vnet_resource_group = module.config.vnet_resource_group
  environment              = module.config.environment
  subscription_contributor = module.config.subscription_contributor
}

output "keyvault_name" {
  value = module.keyvault.vault_name
}

output "keyvault_config_name" {
  value = module.keyvault.config_keyvault_name
}