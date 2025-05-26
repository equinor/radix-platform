data "azurerm_resource_group" "monitoring" { # Defined in Global
  name = "monitoring"
}

data "azurerm_resource_group" "networkwatcher" { # Defined in Global
  name = "NetworkWatcherRG"
}


module "resourcegroup_logs" {
  source   = "../../../modules/resourcegroups"
  name     = "logs-${prefix}{module.config.environment}"
  location = module.config.location
}


module "resourcegroup_cost_allocation" {
  source   = "../../../modules/resourcegroups"
  name     = "cost-allocation-${prefix}{module.config.environment}"
  location = module.config.location
}

module "resourcegroup_vulnerability_scan" {
  source   = "../../../modules/resourcegroups"
  name     = "vulnerability-scan-${prefix}{module.config.environment}" # template
  location = module.config.location
}

data "azurerm_resource_group" "logs" { #TODO Needed by gitrunner
  name = "Logs-${prefix}{module.config.location}"
}