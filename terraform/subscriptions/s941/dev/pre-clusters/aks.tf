data "azurerm_app_configuration" "this" {
  name                = "radix-appconfig-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

data "azurerm_app_configuration_key" "ip_range" {
  configuration_store_id = data.azurerm_app_configuration.this.id
  key                    = "kubernetes-api-auth-ip-range"
}

data "azurerm_user_assigned_identity" "aks" {
  name                = "radix-id-aks-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

data "azurerm_user_assigned_identity" "akskubelet" {
  name                = "radix-id-akskubelet-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

data "azurerm_log_analytics_workspace" "defender" {
  name                = "radix-logs-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

data "azurerm_log_analytics_workspace" "containers" {
  name                = "radix-container-logs-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = module.config.vnet_resource_group
}

module "aks" {
  source                      = "../../../modules/aks"
  for_each                    = module.config.cluster
  cluster_name                = each.key
  resource_group              = module.config.cluster_resource_group
  location                    = module.config.location
  dns_prefix                  = lookup(module.config.cluster[each.key], "dns_prefix", "")
  outbound_ip_address_ids     = module.config.networksets[each.value.networkset].egress
  storageaccount_id           = data.azurerm_storage_account.this.id
  address_space               = module.config.networksets[each.value.networkset].vnet
  enviroment                  = module.config.environment
  aks_version                 = each.value.aksversion
  authorized_ip_ranges        = split(",", data.azurerm_app_configuration_key.ip_range.value)
  nodepools                   = var.nodepools
  systempool                  = var.systempool
  identity_aks                = data.azurerm_user_assigned_identity.aks.id
  identity_kublet_client      = data.azurerm_user_assigned_identity.akskubelet.client_id
  identity_kublet_object      = data.azurerm_user_assigned_identity.akskubelet.principal_id
  identity_kublet_identity_id = data.azurerm_user_assigned_identity.akskubelet.id
  defender_workspace_id       = data.azurerm_log_analytics_workspace.defender.id
  containers_workspace_id     = data.azurerm_log_analytics_workspace.containers.id
  network_policy              = each.value.network_policy
  developers                  = module.config.developers
  subscription                = module.config.subscription
  vnethub_id                  = data.azurerm_virtual_network.hub.id
  dnszones                    = module.config.private_dns_zones_names
  cluster_vnet_resourcegroup  = data.azurerm_virtual_network.hub.resource_group_name
  active_cluster              = lookup(module.config.cluster[each.key], "activecluster", false)
  hostencryption              = lookup(module.config.cluster[each.key], "hostencryption", false)
}

locals {
  flattened_vnets = {
    for key, value in module.aks : key => {
      cluster     = key
      vnet_name   = value.vnet.name
      vnet_id     = value.vnet.id
      subnet_id   = value.subnet.id
      subnet_name = value.subnet.name
    }
  }
  clusters = {
    for key, value in module.config.cluster : key => {
      cluster   = key
      ingressIp = module.config.networksets[module.config.cluster[key].networkset].ingressIP
    }
  }
}

output "vnets" {
  value = local.flattened_vnets
}

output "clusters" {
  value = local.clusters
}

output "oidc_issuer_url" {
  value = module.clusters.oidc_issuer_url
}