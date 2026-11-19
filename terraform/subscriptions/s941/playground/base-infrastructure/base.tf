module "base" {
  source                               = "../../../modules/base-infrastructure"
  gitrunner_federated_credential_name  = "radix-platform-env-${module.config.environment}"
  gitrunner_locker_name                = "radix-id-gitrunner-locker-${module.config.environment}"
  gitrunner_locker_resource_group_name = module.config.common_resource_group
  keyvault_lock_creator_role_name      = "Radix Key Vault Lock Creator ${module.config.environment}"
  keyvault_config_name                 = "radix-config-${module.config.environment}"
  keyvault_config_resource_group_name  = module.config.common_resource_group
  keyvault_name                        = "radix-keyv-${module.config.environment}"
  keyvault_resource_group_name         = module.config.common_resource_group
  keyvault_secrets_user_id             = module.acr.azurerm_container_registry_credential_id
  keyvault_subscription_contributor    = module.config.subscription_contributor
  vnet_resource_group                  = module.config.vnet_resource_group
  common_resource_group                = module.config.common_resource_group
  location                             = module.config.location
  subscription_id                      = data.azurerm_subscription.current.id
  terraform_state_storage_account_id   = data.azurerm_storage_account.terraform_state.id

  easyauth = {
    app_display_name          = "Radix EasyAuth Playground"
    app_owners                = data.azuread_group.radix_az.members
    allowed_group_names       = ["Equinor All"]
    dex_mi_name               = "radix-id-easyauth-dex-${module.config.environment}"
    postgres_server_name      = "psql-radix-easyauth-${module.config.environment}"
    postgres_admin_group_name = data.azuread_group.sql_admin.display_name
    postgres_sku_name         = "B_Standard_B1ms"
  }
}

output "easyauth_app_client_id" {
  value = module.base.easyauth_app_client_id
}

output "easyauth_dex_identity_client_id" {
  value = module.base.easyauth_dex_identity_client_id
}

output "easyauth_postgres_host" {
  value = module.base.easyauth_postgres_host
}

output "radix_id_gitrunner_locker_client_id" {
  value = module.base.radix_id_gitrunner_locker_client_id
}
