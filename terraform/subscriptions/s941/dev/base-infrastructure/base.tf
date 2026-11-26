module "base" {
  source                                         = "../../../modules/base-infrastructure"
  ampls_enabled                                  = module.config.ampls_enabled
  ampls_name                                     = "radix-ampls-${module.config.environment}"
  ampls_resource_group                           = module.config.common_resource_group
  ampls_private_endpoint_name                    = "pe-ampls-${module.config.environment}"
  common_resource_group                          = module.config.common_resource_group
  gitrunner_federated_credential_name            = "radix-platform-env-${module.config.environment}"
  gitrunner_locker_name                          = "radix-id-gitrunner-locker-${module.config.environment}"
  gitrunner_locker_resource_group_name           = module.config.common_resource_group
  keyvault_lock_creator_role_name                = "Radix Key Vault Lock Creator ${module.config.environment}"
  keyvault_config_name                           = "radix-config-${module.config.environment}"
  keyvault_config_resource_group_name            = module.config.common_resource_group
  keyvault_name                                  = "radix-keyv-${module.config.environment}"
  keyvault_resource_group_name                   = module.config.common_resource_group
  keyvault_secrets_user_id                       = module.acr.azurerm_container_registry_credential_id
  keyvault_subscription_contributor              = module.config.subscription_contributor
  location                                       = module.config.location
  network_security_perimeter_name                = "network-perimeter-${module.config.environment}"
  network_security_perimeter_resource_group_name = module.config.common_resource_group
  subscription_id                                = data.azurerm_subscription.current.id
  terraform_state_storage_account_id             = data.azurerm_storage_account.terraform_state.id
  virtual_network_private_dns_zone               = module.azurerm_virtual_network.data.private_dns_zone
  virtual_network_subnet_id                      = module.azurerm_virtual_network.azurerm_subnet_id
  vnet_resource_group                            = module.config.vnet_resource_group

  easyauth = {
    app_display_name          = "Radix EasyAuth Dev"
    app_owners                = data.azuread_group.radix_az.members
    allowed_group_objectids   = ["a636269f-a967-45b2-bb4e-3e02dbb624a2"] # Equinor All group object ID
    dex_mi_name               = "radix-id-easyauth-dex-${module.config.environment}"
    postgres_server_name      = "psql-radix-easyauth-${module.config.environment}"
    postgres_admin_group_name = data.azuread_group.sql_admin.display_name
    postgres_sku_name         = "B_Standard_B1ms"
  }
  depends_on = [module.azurerm_virtual_network]
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
