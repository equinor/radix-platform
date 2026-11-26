terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110.0, < 5.0.0"
    }
  }
}

resource "azurerm_log_analytics_workspace" "this" {
  name                               = var.workspace_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  sku                                = var.sku
  retention_in_days                  = var.retention_in_days
  internet_ingestion_enabled         = !var.ampls_enabled
  internet_query_enabled             = !var.ampls_enabled
  local_authentication_disabled      = true
  allow_resource_only_permissions    = false
  reservation_capacity_in_gb_per_day = var.acr_reservation
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_monitor_private_link_scoped_service" "this" {
  count = var.ampls_enabled ? 1 : 0

  name                = var.workspace_name
  resource_group_name = var.ampls_resource_group
  scope_name          = var.ampls_scope_name
  linked_resource_id  = azurerm_log_analytics_workspace.this.id
}

output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}
