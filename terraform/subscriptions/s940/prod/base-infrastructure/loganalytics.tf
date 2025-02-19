module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${module.config.environment}"
  resource_group_name           = "common-platform" #TODO
  location                      = module.resourcegroup_logs.data.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

module "loganalytics_containers" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-container-logs-prod" #TODO
  resource_group_name           = "Logs"                      #TODO
  location                      = module.resourcegroup_logs.data.location
  retention_in_days             = 30
  local_authentication_disabled = false
  sku                           = "CapacityReservation"
  acr_reservation               = 100
}