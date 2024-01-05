module "la" {
  source                        = "github.com/equinor/terraform-azurerm-log-analytics?ref=v2.1.1"
  workspace_name                = var.workspace_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  retention_in_days             = var.retention_in_days
  local_authentication_disabled = var.local_authentication_disabled

}


