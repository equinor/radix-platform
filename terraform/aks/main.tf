provider "azurerm" {
  features {}
}

locals {
  whitelist_ips              = jsondecode(textdecodebase64("${data.azurerm_key_vault_secret.whitelist_ips.value}", "UTF-8"))
  AZ_RESOURCE_GROUP_VNET_HUB = "cluster-vnet-hub-${var.RADIX_ZONE}"
}

data "azurerm_key_vault" "keyvault_env" {
  name                = "radix-vault-dev"
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
}

data "azurerm_key_vault_secret" "whitelist_ips" {
  name         = "kubernetes-api-server-whitelist-ips-dev"
  key_vault_id = data.azurerm_key_vault.keyvault_env.id
}

resource "azurerm_resource_group" "rg_clusters" {
  name     = var.AZ_RESOURCE_GROUP_CLUSTERS
  location = var.AZ_LOCATION
}

module "aks" {
  source = "github.com/equinor/radix-terraform-azurerm-aks?ref=v0.1.0-alpha"

  cluster_name = var.cluster_name
  AZ_LOCATION  = var.AZ_LOCATION

  # Resource groups
  AZ_RESOURCE_GROUP_CLUSTERS = azurerm_resource_group.rg_clusters.name
  AZ_RESOURCE_GROUP_COMMON   = var.AZ_RESOURCE_GROUP_COMMON
  AZ_RESOURCE_GROUP_VNET_HUB = local.AZ_RESOURCE_GROUP_VNET_HUB

  # network
  # AZ_PRIVATE_DNS_ZONES = var.AZ_PRIVATE_DNS_ZONES
  whitelist_ips = length(local.whitelist_ips.whitelist) != 0 ? [for x in local.whitelist_ips.whitelist : x.ip] : null

  # AKS
  aks_node_pool_name     = var.aks_node_pool_name
  aks_node_pool_vm_size  = var.aks_node_pool_vm_size
  aks_node_count         = var.aks_node_count
  aks_kubernetes_version = var.aks_kubernetes_version

  # Manage identity
  MI_AKSKUBELET = var.MI_AKSKUBELET
  MI_AKS        = var.MI_AKS

  # Radix
  RADIX_ZONE        = var.RADIX_ZONE
  RADIX_ENVIRONMENT = var.RADIX_ENVIRONMENT
}

resource "azurerm_redis_cache" "redis_cache_web_console" {
  count = length(var.RADIX_WEB_CONSOLE_ENVIRONMENTS)

  name                          = "${var.cluster_name}-${var.RADIX_WEB_CONSOLE_ENVIRONMENTS[count.index]}"
  resource_group_name           = azurerm_resource_group.rg_clusters.name
  location                      = var.AZ_LOCATION
  capacity                      = "1"
  family                        = "C"
  sku_name                      = "Basic"
  public_network_access_enabled = true
  redis_configuration {
    maxmemory_reserved              = "125"
    maxfragmentationmemory_reserved = "125"
    maxmemory_delta                 = "125"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "cluster_link" {
  count                 = length(var.AZ_PRIVATE_DNS_ZONES)
  name                  = "${var.cluster_name}-link"
  resource_group_name   = local.AZ_RESOURCE_GROUP_VNET_HUB
  private_dns_zone_name = var.AZ_PRIVATE_DNS_ZONES[count.index]
  virtual_network_id    = module.aks.vnet_cluster.id
  registration_enabled  = false
}
