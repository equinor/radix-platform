data "azurerm_subscription" "current" {}

# module "loganalytics" {
#   source                        = "../../../modules/log-analytics"
#   workspace_name                = local.log_analytics_workspace.name
#   resource_group_name           = local.log_analytics_workspace.resource_group
#   location                      = local.external_outputs.common.data.location
#   retention_in_days             = 30
#   local_authentication_disabled = false

# }
module "keyvault" {
  source                      = "../../../modules/key-vault"
  location                    = local.external_outputs.common.data.location
  vault_name                  = local.key_vault.name
  resource_group_name         = local.key_vault.resource_group
  tenant_id                   = data.azurerm_subscription.current.tenant_id
  log_analytics_workspace_id  = local.external_outputs.common.workspace_id
  soft_delete_retention_days  = local.key_vault.soft_delete_retention_days
  enable_rbac_authorization   = local.key_vault.enable_rbac_authorization
  purge_protection_enabled    = local.key_vault.purge_protection_enabled
  network_acls_default_action = local.key_vault.network_acls_default_action
  access_policies             = local.key_vault.access_policies
  # depends_on                  = [module.loganalytics]
}

# resource "azurerm_management_lock" "loganalytics" {
#   name       = "${local.log_analytics_workspace.name}-lock"
#   scope      = module.loganalytics.data.workspace_id
#   lock_level = "CanNotDelete"
#   notes      = "To prevent ${local.log_analytics_workspace.name} from being deleted"
#   depends_on = [module.loganalytics]
# }

# resource "azurerm_management_lock" "keyvault" {
#   name       = "${local.key_vault.name}-lock"
#   scope      = module.keyvault.data.vault_id
#   lock_level = "CanNotDelete"
#   notes      = "To prevent ${local.key_vault.name} from being deleted"
#   depends_on = [module.keyvault]
# }
