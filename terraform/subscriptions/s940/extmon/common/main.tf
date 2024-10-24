module "config" {
  source = "../../../modules/config"
}

###Migrated from 'Virtualnetwork' start

module "vnet_resourcegroup" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.vnet_resource_group
  location = module.config.location
}

module "azurerm_virtual_network" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = module.config.environment
  vnet_resource_group = module.vnet_resourcegroup.data.name
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.vnet_resourcegroup]
}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.config.cluster_resource_group
  publicipprefixname  = "ippre-ingress-radix-aks-${module.config.environment}-${module.config.location}-001"
  pipprefix           = "ingress-radix-aks"
  pippostfix          = module.config.location
  enviroment          = module.config.environment
  prefix_length       = 30
  # zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.config.cluster_resource_group
  publicipprefixname  = "ippre-radix-aks-${module.config.environment}-northeurope-001"
  pipprefix           = "radix-aks"
  pippostfix          = module.config.location
  enviroment          = module.config.environment
  prefix_length       = 30
}


output "vnet_hub_id" {
  value = module.azurerm_virtual_network.data.vnet_hub.id
}

output "vnet_subnet_id" {
  value = module.azurerm_virtual_network.data.vnet_subnet.id
}

output "public_ip_prefix_ids" {
  value = {
    egress_id  = module.azurerm_public_ip_prefix_egress.data.id
    ingress_id = module.azurerm_public_ip_prefix_ingress.data.id
  }
}

###Migrated from 'Virtualnetwork' end

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

data "azurerm_virtual_network" "this" {
  name                = "vnet-hub"
  resource_group_name = module.config.vnet_resource_group
}

data "azurerm_key_vault_secret" "this" {
  name         = "storageaccounts-ip-rule"
  key_vault_id = module.config.backend.ip_key_vault_id
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
  ip_rule                  = data.azurerm_key_vault_secret.this.value
  log_analytics_id         = module.loganalytics.workspace_id
}

output "workspace_id" {
  value = module.loganalytics.workspace_id
}

output "log_storageaccount_id" {
  value = module.storageaccount["log"].data.id
}