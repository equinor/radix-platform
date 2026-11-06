module "base" {
  source                             = "../../../modules/base"
  environment                        = module.config.new_environment
  locker_environment                 = module.config.new_environment
  location                           = module.config.location
  subscription_id                    = data.azurerm_subscription.current.id
  common_resource_group_name         = module.config.common_resource_group
  terraform_state_storage_account_id = data.azurerm_storage_account.terraform_state.id
  key_vault_id                       = module.keyvault.azurerm_key_vault_id
  enable_resource_locks              = true
  clusters_resource_group_id         = module.resourcegroup_clusters.data.id
}
moved {
  from = module.keyvault_lock_creator_role
  to   = module.base.module.keyvault_lock_creator_role
}
moved {
  from = module.radix_id_gitrunner_locker
  to   = module.base.module.radix_id_gitrunner_locker
}

output "radix_id_gitrunner_locker_client_id" {
  value = module.base.radix_id_gitrunner_locker_client_id
}