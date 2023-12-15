module "la" {
  source              = "github.com/equinor/terraform-azurerm-log-analytics?ref=v2.1.1"
  workspace_name      = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  

}


# resource "azurerm_log_analytics_workspace" "this" {
#   name                          = var.workspace_name
#   resource_group_name           = var.resource_group_name
#   location                      = var.location
#   local_authentication_disabled = var.local_authentication_disabled
#   sku                           = "PerGB2018"
#   retention_in_days             = var.retention_in_days

#   tags = var.tags
# }

# resource "azurerm_monitor_diagnostic_setting" "this" {
#   name                       = "audit-logs"
#   target_resource_id         = azurerm_log_analytics_workspace.this.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

#   # Ref: https://registry.terraform.io/providers/hashicorp/azurerm/3.65.0/docs/resources/monitor_diagnostic_setting#log_analytics_destination_type
#   log_analytics_destination_type = null

#   dynamic "enabled_log" {
#     for_each = toset(var.diagnostic_setting_enabled_log_categories)

#     content {
#       category = enabled_log.value
#     }
#   }

#   metric {
#     category = "AllMetrics"
#     enabled  = true

#     retention_policy {
#       days    = 0
#       enabled = false
#     }
#   }
# }
