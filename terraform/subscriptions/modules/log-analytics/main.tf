resource "azurerm_log_analytics_workspace" "this" {
  name                               = var.workspace_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  sku                                = var.sku
  retention_in_days                  = var.retention_in_days
  local_authentication_disabled      = true # Disables shared key/API key access, forcing Azure AD authentication
  allow_resource_only_permissions    = false                             # Disables resource-context access, requiring workspace-level RBAC to query logs. This is a security best practice to prevent unauthorized access to logs from resources with inherited permissions.
  reservation_capacity_in_gb_per_day = var.acr_reservation
  tags = {
    IaC = "terraform"
  }
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.this.id

}

