module "keyvault" {
  source              = "../../../modules/key-vault"
  location            = module.config.location
  vault_name          = "radix-keyv-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  vnet_resource_group = module.config.vnet_resource_group
  # kv_secrets_user_id  = module.acr.azurerm_container_registry_credential_id
  appconfig_sku = module.config.cluster_type == "development" ? "developer" : "standard"
  environment   = module.config.environment

}

output "keyvault_name" {
  value = module.keyvault.vault_name
}