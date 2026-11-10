module "base" {
  source                               = "../../../modules/base-infrastructure"
  clusters_resource_group_id           = module.resourcegroup_clusters.data.id
  enable_resource_locks                = true
  gitrunner_federated_credential_name  = "radix-platform-env-${module.config.new_environment}"
  gitrunner_locker_name                = "radix-id-gitrunner-locker-${module.config.new_environment}"
  gitrunner_locker_resource_group_name = module.config.common_resource_group
  keyvault_lock_creator_role_name      = "Radix Key Vault Lock Creator ${module.config.new_environment}"
  keyvault_config_name                 = "radix-config-${module.config.environment}"
  keyvault_config_resource_group_name  = "common-${module.config.new_environment}"
  keyvault_name                        = "radix-keyv-${module.config.environment}"
  keyvault_resource_group_name         = module.config.common_resource_group
  keyvault_secrets_user_id             = module.acr.azurerm_container_registry_credential_id
  keyvault_subscription_contributor    = module.config.subscription_contributor
  keyvault_vnet_resource_group         = module.config.vnet_resource_group
  location                             = module.config.location
  managed_resource_group_names         = ["common-${module.config.new_environment}"] # Added managed resource group "common-c1" for the new environment
  subscription_id                      = data.azurerm_subscription.current.id
  terraform_state_storage_account_id   = data.azurerm_storage_account.terraform_state.id
}

output "radix_id_gitrunner_locker_client_id" {
  value = module.base.radix_id_gitrunner_locker_client_id
}