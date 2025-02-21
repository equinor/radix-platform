data "azurerm_resource_group" "common" { # Defined in Global
  name = "common"
}
data "azurerm_resource_group" "monitoring" { # Defined in Global
  name = "monitoring"
}

data "azurerm_resource_group" "networkwatcher" { # Defined in Global
  name = "NetworkWatcherRG"
}

module "resourcegroup_common" { #ok
  source   = "../../../modules/resourcegroups"
  name     = module.config.common_resource_group
  location = module.config.location
}

module "resourcegroup_clusters" { #ok 
  source   = "../../../modules/resourcegroups"
  name     = module.config.cluster_resource_group
  location = module.config.location
}

module "resourcegroup_logs" {
  source   = "../../../modules/resourcegroups"
  name     = "logs-${module.config.environment}"
  location = module.config.location
}

module "resourcegroup_vnet" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.vnet_resource_group
  location = module.config.location
}

data "azurerm_resource_group" "logs" { #TODO Needed by gitrunner
  name = "Logs"
}

