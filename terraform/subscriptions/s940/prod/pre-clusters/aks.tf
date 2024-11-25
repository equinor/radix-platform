data "azurerm_user_assigned_identity" "aks" {
  name                = "id-radix-aks-production-northeurope" #TODO
  resource_group_name = "common"
}

data "azurerm_user_assigned_identity" "akskubelet" {
  name                = "id-radix-akskubelet-production-northeurope" #TODO
  resource_group_name = "common"
}

data "azurerm_log_analytics_workspace" "defender" {
  name                = module.config.log_analytics_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_log_analytics_workspace" "containers" {
  name                = "radix-container-logs-prod" #TODO // oms_agent
  resource_group_name = "logs"
}

module "aks" {
  source                      = "../../../modules/aks"
  for_each                    = var.aksclusters
  cluster_name                = each.key
  resource_group              = "clusters" # TODO module.config.cluster_resource_group
  location                    = module.config.location
  subnet_id                   = each.value.subnet_id
  dns_prefix                  = "${each.key}-clusters-${substr(module.config.subscription, 0, 6)}" #TODO
  clustertags                 = each.value.clustertags
  outbound_ip_address_ids     = each.value.outbound_ip_address_ids
  node_os_upgrade_channel     = each.value.node_os_upgrade_channel
  storageaccount_id           = data.azurerm_storage_account.this.id
  address_space               = each.value.ip
  enviroment                  = module.config.environment
  aks_version                 = each.value.aksversion
  authorized_ip_ranges        = var.authorized_ip_ranges
  nodepools                   = var.nodepools
  systempool                  = var.systempool
  identity_aks                = data.azurerm_user_assigned_identity.aks.id
  identity_kublet_client      = data.azurerm_user_assigned_identity.akskubelet.client_id
  identity_kublet_object      = data.azurerm_user_assigned_identity.akskubelet.principal_id
  identity_kublet_identity_id = data.azurerm_user_assigned_identity.akskubelet.id
  # defender_workspace_id       = data.azurerm_log_analytics_workspace.defender.id
  defender_workspace_id     = data.azurerm_log_analytics_workspace.containers.id
  containers_workspace_id   = data.azurerm_log_analytics_workspace.containers.id
  cost_analysis             = each.value.cost_analysis
  workload_identity_enabled = each.value.workload_identity_enabled
  network_policy            = each.value.network_policy
  developers                = module.config.developers
  ingressIP                 = each.value.ingressIP
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
}

output "vnets" {
  value = local.flattened_vnets
}
