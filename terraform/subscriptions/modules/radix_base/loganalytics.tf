module "loganalytics" {
  source                        = "../../modules/log-analytics"
  workspace_name                = "radix-logs-${var.environment}"
  resource_group_name           = module.resourcegroup_common.data.name
  location                      = module.resourcegroup_common.data.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

module "loganalytics_containers" {
  source                        = "../../modules/log-analytics"
  workspace_name                = "radix-container-logs-${var.environment}"
  resource_group_name           = module.resourcegroup_common.data.name
  location                      = module.resourcegroup_common.data.location
  retention_in_days             = 30
  local_authentication_disabled = false
}