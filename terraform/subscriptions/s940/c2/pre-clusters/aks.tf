data "azurerm_user_assigned_identity" "aks" {
  name                = "id-radix-aks-c2-prod" #TODO radix-id-aks-${module.config.environment} 
  resource_group_name = "common-westeurope"    #TODO module.config.common_resource_group
}

data "azurerm_user_assigned_identity" "akskubelet" {
  name                = "id-radix-akskubelet-c2-prod" #TODO radix-id-akskubelet-${module.config.environment}
  resource_group_name = "common-westeurope"           #TODO module.config.common_resource_group
}

data "azurerm_log_analytics_workspace" "defender" {
  name                = module.config.log_analytics_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_log_analytics_workspace" "containers" {
  name                = "radix-container-logs-c2-prod"
  resource_group_name = "logs-westeurope"
}

module "aks" {
  source                      = "../../../modules/aks"
  for_each                    = module.config.cluster
  cluster_name                = each.key
  resource_group              = module.config.cluster_resource_group
  location                    = module.config.location
  dns_prefix                  = lookup(module.config.cluster[each.key], "dns_prefix", "")
  outbound_ip_address_ids     = local.clustersets[each.value.networkset].egress
  storageaccount_id           = data.azurerm_storage_account.this.id
  address_space               = local.clustersets[each.value.networkset].vnet
  enviroment                  = module.config.environment
  aks_version                 = each.value.aksversion
  authorized_ip_ranges        = var.authorized_ip_ranges
  nodepools                   = var.nodepools
  systempool                  = var.systempool
  identity_aks                = data.azurerm_user_assigned_identity.aks.id
  identity_kublet_client      = data.azurerm_user_assigned_identity.akskubelet.client_id
  identity_kublet_object      = data.azurerm_user_assigned_identity.akskubelet.principal_id
  identity_kublet_identity_id = data.azurerm_user_assigned_identity.akskubelet.id
  defender_workspace_id       = data.azurerm_log_analytics_workspace.containers.id
  containers_workspace_id     = data.azurerm_log_analytics_workspace.containers.id
  network_policy              = each.value.network_policy
  developers                  = module.config.developers
  ingressIP                   = local.clustersets[each.value.networkset].ingressIP
  subscription                = module.config.subscription
  autostartupschedule         = lookup(module.config.cluster[each.key], "autostartupschedule", false)
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
  clustersets = jsondecode(data.azurerm_key_vault_secret.clustersets.value)
}

output "vnets" {
  value = local.flattened_vnets
}
