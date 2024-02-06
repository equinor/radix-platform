# module "la" {
#   source                        = "github.com/equinor/terraform-azurerm-log-analytics?ref=v2.1.1"
#   workspace_name                = var.workspace_name
#   resource_group_name           = var.resource_group_name
#   location                      = var.location
#   retention_in_days             = var.retention_in_days
#   local_authentication_disabled = var.local_authentication_disabled
# }

resource "azurerm_log_analytics_workspace" "this" {
  name                          = var.workspace_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "PerGB2018"
  retention_in_days             = var.retention_in_days
  local_authentication_disabled = var.local_authentication_disabled
}


