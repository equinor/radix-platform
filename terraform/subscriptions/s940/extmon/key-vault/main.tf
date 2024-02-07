data "azurerm_subscription" "current" {}

module "config" {
  source = "../../../modules/config"
}

module "keyvault" {
  for_each                    = var.keyvaults
  source                      = "../../../modules/key-vault"
  location                    = module.config.location
  vault_name                  = each.key
  resource_group_name         = each.value.resource_group
  tenant_id                   = data.azurerm_subscription.current.tenant_id
  soft_delete_retention_days  = each.value.soft_delete_retention_days
  enable_rbac_authorization   = each.value.enable_rbac_authorization
  purge_protection_enabled    = each.value.purge_protection_enabled
  network_acls_default_action = each.value.network_acls_default_action
}
