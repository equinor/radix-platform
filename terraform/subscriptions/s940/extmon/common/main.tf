module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.common_resource_group
  location = module.config.location
}

module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${module.config.environment}"
  resource_group_name           = module.config.common_resource_group
  location                      = module.config.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

data "azurerm_resource_group" "logs" {
  name = "Logs"
}

data "azurerm_resource_group" "clusters" {
  name = "clusters-${module.config.environment}"
}

data "azurerm_resource_group" "networkwatcher" {
  name = "NetworkWatcherRG"
}

data "azurerm_key_vault" "this" {
  name                = "radix-keyv-${module.config.environment}"
  resource_group_name = "common-${module.config.environment}"
}

data "azurerm_virtual_network" "this" {
  name                = "vnet-hub"
  resource_group_name = module.config.vnet_resource_group
}

data "azurerm_subnet" "this" {
  name                 = "private-links"
  resource_group_name  = module.config.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.this.name
}

data "azurerm_container_registry" "cache" {
  name                = "radixplatformcache"
  resource_group_name = "common-platform"
}

resource "azurerm_private_endpoint" "cache" {
  name                = "pe-radix-acr-cache-${module.config.environment}"
  resource_group_name = module.config.vnet_resource_group
  location            = module.config.location
  subnet_id           = data.azurerm_subnet.this.id
  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = data.azurerm_container_registry.cache.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_private_dns_a_record" "cache" {
  for_each = {
    for k, v in azurerm_private_endpoint.cache.custom_dns_configs : v.fqdn => v #if length(regexall("\\.", v.fqdn)) >= 3
  }
  name                = replace(each.key, ".azurecr.io", "")
  zone_name           = "privatelink.azurecr.io"
  resource_group_name = module.config.vnet_resource_group
  ttl                 = 300
  records             = toset(each.value.ip_addresses)
  tags = {
    IaC = "terraform"
  }
  depends_on = [azurerm_private_endpoint.cache]
}

module "storageaccount" {
  source                   = "../../../modules/storageaccount"
  for_each                 = var.storageaccounts
  name                     = "radix${each.key}${module.config.environment}"
  tier                     = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  resource_group_name      = each.value.resource_group_name
  location                 = each.value.location
  environment              = module.config.environment
  kind                     = each.value.kind
  change_feed_enabled      = each.value.change_feed_enabled
  versioning_enabled       = each.value.versioning_enabled
  backup                   = each.value.backup
  subnet_id                = data.azurerm_subnet.this.id
  vnet_resource_group      = module.config.vnet_resource_group
  lifecyclepolicy          = each.value.lifecyclepolicy
  # ip_rule                   = data.azurerm_key_vault_secret.this.value
  log_analytics_id          = module.loganalytics.workspace_id
  shared_access_key_enabled = each.value.shared_access_key_enabled #Needed in module create container when running apply
}

module "radix_id_gitrunner" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    privatelink-contributor = {
      role     = "Radix Privatelink rbac-${module.config.subscription_shortname}"
      scope_id = "/subscriptions/${module.config.subscription}"
    }
    blob_contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = "${module.config.backend.terraform_storage_id}"
    }
    storage_blob_contributor = {
      role     = "Storage Blob Data Contributor" # Needed to read blobdata
      scope_id = "${module.config.backend.terraform_storage_id}"
    }
    common_contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = "${module.resourcegroups.data.id}"
    }
    logs_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.logs.id}"
    }
    clusters_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.clusters.id}"
    }
    networkwatcher_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.networkwatcher.id}"
    }
    keyvault_contributor = {
      role     = "Key Vault Secrets User" # Needed to read secrets
      scope_id = "${data.azurerm_key_vault.this.id}"
    }
    vnet_contributor = {
      role     = "Contributor"
      scope_id = "/subscriptions/${module.config.subscription}/resourceGroups/${data.azurerm_virtual_network.this.resource_group_name}"
    }
  }
  federated_credentials = {
    radix-id-gitrunner = {
      name    = "radix-id-gitrunner-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix:environment:${module.config.environment}"
    },
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:environment:${module.config.environment}"
    }
  }
}

output "workspace_id" {
  value = module.loganalytics.workspace_id
}

output "log_storageaccount_id" {
  value = module.storageaccount["log"].data.id
}