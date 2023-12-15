# module "loganalytics" {
#   source              = "../../../modules/log-analytics"
#   workspace_name      = local.log_analytics_workspace.name
#   resource_group_name = local.log_analytics_workspace.resource_group
#   location            = local.external_outputs.common.data.location
#   retention_in_days   = 30
# }

# module "keyvault" {
#   source                     = "../../../modules/key-vault"
#   location                   = local.external_outputs.common.data.location
#   vault_name                 = local.key_vault.name
#   resource_group_name        = local.key_vault.resource_group
#   log_analytics_workspace_id = module.loganalytics.workspace_id
#   depends_on = [ module.loganalytics ]
# }


# locals {
#   access_policies = [
#     for p in var.access_policies : {
#       tenant_id               = data.azurerm_client_config.current.tenant_id
#       application_id          = ""
#       object_id               = p.object_id
#       secret_permissions      = p.secret_permissions
#       certificate_permissions = p.certificate_permissions
#       key_permissions         = p.key_permissions
#       storage_permissions     = []
#     }
#   ]
# }

# data "azurerm_subscription" "current" {}

# module "log_analytics" {
#   source              = "github.com/equinor/terraform-azurerm-log-analytics?ref=v2.1.1"
#   workspace_name      = local.log_analytics_workspace.name
#   resource_group_name = local.log_analytics_workspace.resource_group
#   location            = local.external_outputs.common.data.location
# }


# module "kv" {
#   source              = "github.com/equinor/terraform-azurerm-key-vault?ref=v11.1.0"
#   name                = var.vault_name
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   sku_name            = "standard"
#   tenant_id           = data.azurerm_client_config.current.tenant_id

#   soft_delete_retention_days = var.soft_delete_retention_days
#   purge_protection_enabled   = var.purge_protection_enabled

#   enabled_for_deployment          = false
#   enabled_for_disk_encryption     = false
#   enabled_for_template_deployment = false
#   access_policy                   = local.access_policies
#   enable_rbac_authorization       = var.enable_rbac_authorization
#   public_network_access_enabled   = var.public_network_access_enabled


# }

