data "azurerm_key_vault" "this" {
  name                = "radix-keyv-${var.environment}"
  resource_group_name = var.common_resource_group
}

data "azurerm_key_vault_secret" "api_ip" {
  name         = "kubernetes-api-auth-ip-range"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_storage_account" "this" {
  name                = "radixlog${var.environment}"
  resource_group_name = var.common_resource_group
}

data "azurerm_user_assigned_identity" "aks" {
  name                = "radix-id-aks-${var.environment}"
  resource_group_name = var.common_resource_group
}

data "azurerm_user_assigned_identity" "akskubelet" {
  name                = "radix-id-akskubelet-${var.environment}"
  resource_group_name = var.common_resource_group
}

data "azurerm_log_analytics_workspace" "defender" {
  name                = "radix-logs-${var.environment}"
  resource_group_name = var.common_resource_group
}

data "azurerm_log_analytics_workspace" "containers" {
  name                = "radix-container-logs-${var.environment}"
  resource_group_name = var.common_resource_group
}

data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = var.vnet_resource_group
}

module "aks" {
  source                      = "../../modules/aks"
  cluster_name                = var.cluster_name
  resource_group              = var.cluster_resource_group
  location                    = var.location
  dns_prefix                  = var.dns_prefix
  outbound_ip_address_ids     = var.outbound_ip_address_ids
  storageaccount_id           = data.azurerm_storage_account.this.id
  address_space               = var.address_space
  enviroment                  = var.environment
  aks_version                 = var.aks_version
  authorized_ip_ranges        = split(",", nonsensitive(data.azurerm_key_vault_secret.api_ip.value))
  nodepools                   = var.nodepools
  systempool                  = var.systempool
  identity_aks                = data.azurerm_user_assigned_identity.aks.id
  identity_kublet_client      = data.azurerm_user_assigned_identity.akskubelet.client_id
  identity_kublet_object      = data.azurerm_user_assigned_identity.akskubelet.principal_id
  identity_kublet_identity_id = data.azurerm_user_assigned_identity.akskubelet.id
  defender_workspace_id       = data.azurerm_log_analytics_workspace.defender.id
  containers_workspace_id     = data.azurerm_log_analytics_workspace.containers.id
  network_policy              = var.network_policy
  developers                  = var.developers
  subscription                = var.subscription
  vnethub_id                  = data.azurerm_virtual_network.hub.id
  dnszones                    = var.private_dns_zones_names
  cluster_vnet_resourcegroup  = data.azurerm_virtual_network.hub.resource_group_name
  common_resource_group       = var.common_resource_group
  # active_cluster              = lookup(module.config.cluster[each.key], "activecluster", false)
  hostencryption = lookup(module.config.cluster[each.key], "hostencryption", false)
}

# locals {
#   flattened_vnets = {
#     for key, value in module.aks : key => {
#       cluster     = key
#       vnet_name   = value.vnet.name
#       vnet_id     = value.vnet.id
#       subnet_id   = value.subnet.id
#       subnet_name = value.subnet.name
#     }
#   }
#   clusters = {
#     for key, value in module.config.cluster : key => {
#       cluster   = key
#       ingressIp = module.config.networksets[module.config.cluster[key].networkset].ingressIP
#     }
#   }
# }

# output "vnets" {
#   value = local.flattened_vnets
# }

# output "clusters" {
#   value = local.clusters
# }


module "clusters" {
  source              = "../../modules/active-clusters"
  resource_group_name = var.cluster_resource_group
  subscription        = var.subscription
}

output "oidc_issuer_url" {
  value = module.clusters.oidc_issuer_url
}

# output "oidc_issuer_url" {
#   value = module.clusters.oidc_issuer_url
# }

# output "oidc_issuer_url" {
#   value = { for k, v in data.azapi_resource_list.clusters.output.value : v.name => v.properties.oidcIssuerProfile.issuerURL }
# }
