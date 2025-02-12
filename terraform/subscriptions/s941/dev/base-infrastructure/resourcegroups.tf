data "azurerm_resource_group" "common" { # Defined in Global
  name = "common"
}

data "azurerm_resource_group" "logs" { # Defined in Global
  name = "Logs-${module.config.environment}"
}

data "azurerm_resource_group" "monitoring" { # Defined in Global
  name = "monitoring"
}

data "azurerm_resource_group" "networkwatcher" { # Defined in Global
  name = "NetworkWatcherRG"
}

module "resourcegroups_common" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.common_resource_group
  location = module.config.location
}

module "resourcegroups_clusters" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.cluster_resource_group
  location = module.config.location
}

module "resourcegroup_cost_allocation" {
  source   = "../../../modules/resourcegroups"
  name     = "cost-allocation-${module.config.environment}"
  location = module.config.location
}

module "vnet_resourcegroup" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.vnet_resource_group
  location = module.config.location
}

module "resourcegroup_vulnerability_scan" {
  source   = "../../../modules/resourcegroups"
  name     = "vulnerability-scan-${module.config.environment}"
  location = module.config.location
}