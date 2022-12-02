terraform {
  backend "azurerm" {
    resource_group_name  = "s941-tfstate"
    storage_account_name = "radixinfradev"
    container_name       = "tfstate"
    use_azuread_auth     = true
    key                  = "dev.sondredev.terraform.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  # skip_provider_registration = true
  features {}
  # client_id       = "f1e6bc52-9aa4-4ca7-a9ac-b7a19d8f0f86"
  # subscription_id = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  # tenant_id       = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
  # use_oidc        = true
}

locals {
  whitelist_ips              = jsondecode(textdecodebase64("${data.azurerm_key_vault_secret.whitelist_ips.value}", "UTF-8"))
  AZ_RESOURCE_GROUP_VNET_HUB = "cluster-vnet-hub-${var.RADIX_ZONE}"
  # cluster_name               = terraform.workspace
  cluster_name = basename(abspath(path.module))
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
  source = "github.com/equinor/radix-terraform-azurerm-aks?ref=development"

  cluster_name = local.cluster_name
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

  name                          = "${local.cluster_name}-${var.RADIX_WEB_CONSOLE_ENVIRONMENTS[count.index]}"
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
  name                  = "${local.cluster_name}-link"
  resource_group_name   = local.AZ_RESOURCE_GROUP_VNET_HUB
  private_dns_zone_name = var.AZ_PRIVATE_DNS_ZONES[count.index]
  virtual_network_id    = module.aks.vnet_cluster.id
  registration_enabled  = false
}
