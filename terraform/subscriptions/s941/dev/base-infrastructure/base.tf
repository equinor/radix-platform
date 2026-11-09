module "base" {
  source                             = "../../../modules/base-infrastructure"
  environment                        = module.config.environment
  location                           = module.config.location
  subscription_id                    = data.azurerm_subscription.current.id
  common_resource_group_name         = module.config.common_resource_group
  terraform_state_storage_account_id = data.azurerm_storage_account.terraform_state.id
  key_vault_id                       = module.keyvault.azurerm_key_vault_id
}

output "radix_id_gitrunner_locker_client_id" {
  value = module.base.radix_id_gitrunner_locker_client_id
}