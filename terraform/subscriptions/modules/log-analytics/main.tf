resource "azurerm_log_analytics_workspace" "this" {
  name                               = var.workspace_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  sku                                = var.sku
  retention_in_days                  = var.retention_in_days
  reservation_capacity_in_gb_per_day = var.acr_reservation
  tags = {
    IaC = "terraform"
  }
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.this.id

}

