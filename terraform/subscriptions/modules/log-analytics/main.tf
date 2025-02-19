resource "azurerm_log_analytics_workspace" "this" {
  name                               = var.workspace_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  sku                                = var.sku
  retention_in_days                  = var.retention_in_days
  local_authentication_disabled      = var.local_authentication_disabled
  reservation_capacity_in_gb_per_day = var.acr_reservation
  tags = {
    IaC = "terraform"
  }
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.this.id

}

#This is legacy Replaced by monitor settings on the cluster itself. Insights | Monitor settings -> Log Analytics workspace

# resource "azurerm_log_analytics_solution" "containerinsights" {
#   for_each   = startswith(var.workspace_name, "radix-container-logs-")  ? { "${var.workspace_name}" : true } : {}
#   solution_name         = "ContainerInsights"
#   location              = var.location
#   resource_group_name   = var.resource_group_name
#   workspace_resource_id = azurerm_log_analytics_workspace.this.id
#   workspace_name        = azurerm_log_analytics_workspace.this.name

#   plan {
#     publisher = "Microsoft"
#     product   = "OMSGallery/ContainerInsights"
#   }
# }

# resource "azurerm_log_analytics_solution" "vminsights" {
#   for_each   = startswith(var.workspace_name, "radix-container-logs-")  ? { "${var.workspace_name}" : true } : {}
#   solution_name         = "VMInsights"
#   location              = var.location
#   resource_group_name   = var.resource_group_name
#   workspace_resource_id = azurerm_log_analytics_workspace.this.id
#   workspace_name        = azurerm_log_analytics_workspace.this.name

#   plan {
#     publisher = "Microsoft"
#     product   = "OMSGallery/VMInsights"
#   }
# }
