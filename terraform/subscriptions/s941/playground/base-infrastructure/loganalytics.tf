module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${module.config.environment}"
  resource_group_name           = module.config.common_resource_group
  location                      = module.config.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

module "loganalytics_containers" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-container-logs-${module.config.environment}"
  resource_group_name           = "logs-dev"
  location                      = module.resourcegroup_logs.data.location
  retention_in_days             = 30
  local_authentication_disabled = false
}