terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.60.0, < 5.0.0"
    }
  }
}

# The workspace and AMPLS link used to be declared directly in this module.
moved {
  from = azurerm_log_analytics_workspace.this
  to   = module.workspace.azurerm_log_analytics_workspace.this
}

moved {
  from = azurerm_monitor_private_link_scoped_service.this
  to   = module.workspace.azurerm_monitor_private_link_scoped_service.this
}

module "workspace" {
  source               = "../log-analytics-ampls"
  workspace_name       = var.workspace_name
  resource_group_name  = var.resource_group_name
  location             = var.location
  sku                  = var.sku
  retention_in_days    = var.retention_in_days
  acr_reservation      = var.acr_reservation
  ampls_enabled        = var.ampls_enabled
  ampls_scope_name     = var.ampls_scope_name
  ampls_resource_group = var.ampls_resource_group
}

# Without AMPLS the workspace must stay reachable over the internet, which an Enforced perimeter would block.
resource "azurerm_network_security_perimeter_association" "this" {
  count = var.ampls_enabled ? 1 : 0

  name                                  = var.workspace_name
  access_mode                           = "Enforced"
  network_security_perimeter_profile_id = var.network_security_perimeter_profile_id
  resource_id                           = module.workspace.workspace_id
}

output "workspace_id" {
  value = module.workspace.workspace_id
}

