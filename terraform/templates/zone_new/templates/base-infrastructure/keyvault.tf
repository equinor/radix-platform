# data "azurerm_key_vault_secret" "api_ip" {
#   name         = "kubernetes-api-auth-ip-range"
#   key_vault_id = data.azurerm_key_vault.this.id
# }

module "keyvault" {
  source              = "../../../modules/key-vault"
  location            = module.config.location
  vault_name          = "radix-keyv-${prefix}{module.config.environment}"
  resource_group_name = module.config.common_resource_group
  tenant_id           = data.azurerm_subscription.current.tenant_id
  subscription_id     = module.config.backend.subscription_id
  vnet_resource_group = module.config.vnet_resource_group
  ip_rule             = ["143.97.110.1/32"]
  kv_secrets_user_id  = module.acr.azurerm_container_registry_credential_id
  testzone            = module.config.testzone
  depends_on          = [module.azurerm_virtual_network]
}

output "keyvault_name" {
  value = module.keyvault.vault_name
}