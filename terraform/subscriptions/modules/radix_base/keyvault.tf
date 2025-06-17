module "keyvault" {
  source              = "../../modules/key-vault"
  location            = var.location
  vault_name          = var.key_vault_name
  resource_group_name = var.common_resource_group
  vnet_resource_group = var.vnet_resource_group
  kv_secrets_user_id  = module.acr.azurerm_container_registry_credential_id
  testzone            = var.testzone
  depends_on          = [module.azurerm_virtual_network]
}

output "keyvault_name" {
  value = module.keyvault.vault_name
}