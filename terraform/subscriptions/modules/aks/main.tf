resource "azurerm_kubernetes_cluster" "this" {
  name                             = var.cluster_name
  resource_group_name              = var.resource_group
  location                         = var.location
  dns_prefix                       = var.dns_prefix != "" ? var.dns_prefix : "${var.cluster_name}-${var.resource_group}-${substr(var.subscription, 0, 6)}"
  kubernetes_version               = var.aks_version
  node_os_upgrade_channel          = var.enviroment == "dev" || var.enviroment == "playground" || var.enviroment == "extmon" ? "NodeImage" : "None"
  cost_analysis_enabled            = var.cost_analysis
  sku_tier                         = var.enviroment == "dev" ? "Free" : "Standard"
  http_application_routing_enabled = false
  local_account_disabled           = true
  oidc_issuer_enabled              = true
  open_service_mesh_enabled        = false
  azure_policy_enabled             = true
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  workload_identity_enabled = var.enviroment == "extmon" ? true : false
  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings
    ]
  }

  tags = var.autostartupschedule == true ? { "autostartupschedule" = "true" } : {}
  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }
  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [var.developers]
    azure_rbac_enabled     = false
    tenant_id              = var.tenant_id
  }

  default_node_pool {
    name = "systempool"
    # node_public_ip_enabled       = false
    only_critical_addons_enabled = true
    vm_size                      = var.systempool.vm_size
    vnet_subnet_id               = azurerm_subnet.this.id
    auto_scaling_enabled         = true
    fips_enabled                 = false
    # host_encryption_enabled      = false
    min_count = var.systempool.min_nodes
    max_count = var.systempool.max_nodes
    node_labels = {
      "app"           = "system-apps"
      "nodepool-type" = "system"
      "nodepoolos"    = "linux"
    }
    kubelet_disk_type = "OS"
    max_pods          = 110
    tags              = var.systempool.tags #{}
    zones             = []
  }

  auto_scaler_profile {
    balance_similar_node_groups      = false
    empty_bulk_delete_max            = "10"
    expander                         = "random"
    max_graceful_termination_sec     = "600"
    max_node_provisioning_time       = "15m"
    max_unready_nodes                = 3
    max_unready_percentage           = 45
    new_pod_scale_up_delay           = "0s"
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = "0.5"
    scan_interval                    = "10s"
    skip_nodes_with_local_storage    = false
    skip_nodes_with_system_pods      = true
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      var.identity_aks
    ]
  }

  kubelet_identity {
    client_id                 = var.identity_kublet_client
    object_id                 = var.identity_kublet_object
    user_assigned_identity_id = var.identity_kublet_identity_id
  }

  microsoft_defender {
    log_analytics_workspace_id = var.defender_workspace_id
  }
  oms_agent {
    log_analytics_workspace_id      = var.containers_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  network_profile {
    dns_service_ip = "10.2.0.10"
    ip_versions = [
      "IPv4",
    ]
    load_balancer_sku   = "standard"
    network_data_plane  = var.network_policy == "cilium" ? "cilium" : "azure" #var.network_policy #Dependency
    network_plugin      = "azure"
    network_policy      = var.network_policy
    outbound_type       = "loadBalancer"
    network_plugin_mode = var.network_policy == "cilium" ? "overlay" : null
    # pod_cidr            = "10.244.0.0/16"
    # pod_cidrs = [
    #   "10.244.0.0/16",
    # ]
    service_cidr = "10.2.0.0/18"

    load_balancer_profile {
      idle_timeout_in_minutes  = 30
      outbound_ip_address_ids  = var.outbound_ip_address_ids
      outbound_ports_allocated = 4000
      // TODO: Support managed ips for temporary clusters: https://registry.terraform.io/providers/hashicorp/azurerm/3.108.0/docs/resources/kubernetes_cluster#managed_outbound_ip_count-1
    }
  }

  # depends_on = [azurerm_network_security_group.this,azurerm_virtual_network.this,azurerm_network_watcher_flow_log.this]
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each              = { for k, v in var.nodepools : k => v }
  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  auto_scaling_enabled  = true
  max_pods              = 110
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  fips_enabled          = false
  # host_encryption_enabled = false
  node_labels = each.value.node_labels
  # node_public_ip_enabled  = false
  node_taints      = each.value.node_taints
  os_disk_type     = each.value.os_disk_type
  vnet_subnet_id   = azurerm_subnet.this.id
  workload_runtime = "OCIContainer"
  tags             = {}
  zones            = []
  depends_on       = [azurerm_kubernetes_cluster.this]
}

resource "azurerm_management_lock" "aks" {
  for_each   = var.enviroment == "platform" || var.enviroment == "c2" ? { "${var.cluster_name}" : true } : {}
  name       = "${var.cluster_name}-CanNotDelete-Lock"
  scope      = azurerm_kubernetes_cluster.this.id
  lock_level = "CanNotDelete"
  notes      = "IaC : Terraform"
}

