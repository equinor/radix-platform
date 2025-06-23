module "keyvault" {
  source              = "../../modules/key-vault"
  location            = var.location
  vault_name          = var.key_vault_name
  resource_group_name = var.common_resource_group
  vnet_resource_group = var.vnet_resource_group
  kv_secrets_user_id  = module.acr.azurerm_container_registry_credential_id
  testzone            = var.testzone
  appconfig_sku       = module.config.cluster_type == "development" ? "developer" : "standard"
  environment         = module.config.environment
  depends_on          = [module.azurerm_virtual_network]

}

output "keyvault_name" {
  value = module.keyvault.vault_name
}