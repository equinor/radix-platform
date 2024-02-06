# module "kv" {
#   source                      = "github.com/equinor/terraform-azurerm-key-vault?ref=v11.2.0"
#   vault_name                  = var.vault_name
#   log_analytics_workspace_id  = var.log_analytics_workspace_id
#   resource_group_name         = var.resource_group_name
#   location                    = var.location
#   enable_rbac_authorization   = var.enable_rbac_authorization
#   purge_protection_enabled    = var.purge_protection_enabled
#   network_acls_default_action = var.network_acls_default_action
#   access_policies             = var.access_policies
#   diagnostic_setting_name     = var.diagnostic_setting_name
# }

resource "azurerm_key_vault" "this" {
  name                = var.vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  # enabled_for_disk_encryption = true
  tenant_id                  = var.tenant_id
  soft_delete_retention_days = 90
  purge_protection_enabled   = var.purge_protection_enabled

  sku_name = "standard"

  # access_policy {
  #   tenant_id = data.azurerm_client_config.current.tenant_id
  #   object_id = data.azurerm_client_config.current.object_id

  #   key_permissions = [
  #     "Get",
  #   ]

  #   secret_permissions = [
  #     "Get",
  #   ]

  #   storage_permissions = [
  #     "Get",
  #   ]
  # }
}