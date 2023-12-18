module "kv" {
  source                      = "github.com/equinor/terraform-azurerm-key-vault?ref=v11.2.0"
  vault_name                  = var.vault_name
  log_analytics_workspace_id  = var.log_analytics_workspace_id
  resource_group_name         = var.resource_group_name
  location                    = var.location
  enable_rbac_authorization   = var.enable_rbac_authorization
  purge_protection_enabled    = var.purge_protection_enabled
  network_acls_default_action = var.network_acls_default_action
  access_policies             = var.access_policies
  diagnostic_setting_name     = var.diagnostic_setting_name
}
