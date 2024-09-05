data "azurerm_subscription" "current" {}

module "config" {
  source = "../../../modules/config"
}

data "azurerm_key_vault_secret" "this" {
  name         = "storageaccounts-ip-rule"
  key_vault_id = module.config.backend.ip_key_vault_id
}

module "keyvault" {
  for_each            = var.keyvaults
  source              = "../../../modules/key-vault"
  location            = module.config.location
  vault_name          = each.key
  resource_group_name = each.value.resource_group
  tenant_id           = data.azurerm_subscription.current.tenant_id
  # log_analytics_workspace_id  = local.external_outputs.common.workspace_id
  soft_delete_retention_days  = each.value.soft_delete_retention_days
  enable_rbac_authorization   = each.value.enable_rbac_authorization
  kv_secrets_user_id          = each.value.kv_secrets_user_id
  purge_protection_enabled    = each.value.purge_protection_enabled
  network_acls_default_action = each.value.network_acls_default_action
  vnet_resource_group         = module.config.vnet_resource_group
  ip_rule                     = data.azurerm_key_vault_secret.this.value
}
