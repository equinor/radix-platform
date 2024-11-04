resource "azurerm_kubernetes_cluster" "this" {
  location                         = var.location
  name                             = var.cluster_name
  resource_group_name              = var.resource_group
  dns_prefix                       = var.dns_prefix
  azure_policy_enabled             = true
  cost_analysis_enabled            = false
  http_application_routing_enabled = false
  kubernetes_version               = "1.29.8"
  local_account_disabled           = true
  node_os_upgrade_channel          = var.node_os_upgrade_channel
  oidc_issuer_enabled              = true
  lifecycle {
    ignore_changes = [
      key_vault_secrets_provider
    ]
  }

  open_service_mesh_enabled = false
  tags = {
    "autostartupschedule" = var.autostartupschedule
    "migrationStrategy"   = var.migrationStrategy
  }

  api_server_access_profile {
    authorized_ip_ranges = [
      "143.97.110.1/32",
      "143.97.2.129/32",
      "143.97.2.35/32",
      "158.248.121.139/32",
      "213.236.148.45/32",
      "8.29.230.8/32",
      "92.221.23.247/32",
      "92.221.25.155/32",
      "92.221.72.153/32"
    ]
  }
  azure_active_directory_role_based_access_control {
    admin_group_object_ids = var.developers
    azure_rbac_enabled     = false
    tenant_id              = var.tenant_id
  }

  default_node_pool {
    name                         = "systempool"
    node_count                   = 2
    node_public_ip_enabled       = false
    only_critical_addons_enabled = true
    vm_size                      = "Standard_B4as_v2"
    # vnet_subnet_id    = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/clusters-dev/providers/Microsoft.Network/virtualNetworks/vnet-weekly-43/subnets/subnet-weekly-43"
    vnet_subnet_id          = var.subnet_id
    auto_scaling_enabled    = true
    fips_enabled            = false
    host_encryption_enabled = false
    max_count               = 3
    min_count               = 2
    node_labels = {
      "app"           = "system-apps"
      "nodepool-type" = "system"
      "nodepoolos"    = "linux"
    }
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
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
      "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-id-aks-dev",
    ]
  }

  kubelet_identity {
    client_id                 = "3353dc52-333a-4713-a743-09e57bafe736"
    object_id                 = "ea0a9ed4-24e6-4ede-952f-48921cf9829b"
    user_assigned_identity_id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-id-akskubelet-dev"
  }

  microsoft_defender {
    log_analytics_workspace_id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common-dev/providers/Microsoft.OperationalInsights/workspaces/radix-logs-dev"
  }

  dynamic "oms_agent" {
    for_each = var.autostartupschedule == false ? [1] : []
    content {
      log_analytics_workspace_id      = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/Logs-Dev/providers/Microsoft.OperationalInsights/workspaces/radix-container-logs-dev"
      msi_auth_for_monitoring_enabled = true
    }
  }

  network_profile {
    dns_service_ip = "10.2.0.10"
    ip_versions = [
      "IPv4",
    ]
    load_balancer_sku   = "standard"
    network_data_plane  = "cilium" # forces replacement
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    outbound_type       = "loadBalancer"
    pod_cidr            = "10.244.0.0/16"
    pod_cidrs = [
      "10.244.0.0/16",
    ]
    service_cidr = "10.2.0.0/18"
    service_cidrs = [
      "10.2.0.0/18",
    ]
 
    load_balancer_profile {
      idle_timeout_in_minutes = 30
      outbound_ip_address_ids = var.outbound_ip_address_ids
      outbound_ports_allocated = 4000
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "nc24sv3" {
  name                    = "nc24sv3"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = "Standard_NC24s_v3"
  auto_scaling_enabled    = true
  max_count               = 1
  min_count               = 0
  node_count              = 0
  fips_enabled            = false
  host_encryption_enabled = false
  node_labels = {
    "gpu"                  = "nvidia-v100"
    "gpu-count"            = "4"
    "radix-node-gpu"       = "nvidia-v100"
    "radix-node-gpu-count" = "4"
    "sku"                  = "gpu"
  }
  node_public_ip_enabled = false
  node_taints = [
    "radix-node-gpu-count=4:NoSchedule"
  ]
  os_disk_type     = "Ephemeral"
  tags             = {}
  vnet_subnet_id   = var.subnet_id
  workload_runtime = "OCIContainer"
  zones            = []
  depends_on = [ azurerm_kubernetes_cluster.this ]
}

resource "azurerm_kubernetes_cluster_node_pool" "nc12sv3" {
  name                    = "nc12sv3"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = "Standard_NC12s_v3"
  auto_scaling_enabled    = true
  max_count               = 1
  min_count               = 0
  node_count              = 0
  fips_enabled            = false
  host_encryption_enabled = false
  node_labels = {
    "gpu"                  = "nvidia-v100"
    "gpu-count"            = "2"
    "radix-node-gpu"       = "nvidia-v100"
    "radix-node-gpu-count" = "2"
    "sku"                  = "gpu"
  }
  node_public_ip_enabled = false
  node_taints = [
    "radix-node-gpu-count=2:NoSchedule"
  ]
  os_disk_type     = "Ephemeral"
  tags             = {}
  vnet_subnet_id   = var.subnet_id
  workload_runtime = "OCIContainer"
  zones            = []
  depends_on = [ azurerm_kubernetes_cluster.this ]
}

resource "azurerm_kubernetes_cluster_node_pool" "nc6sv3" {
  name                    = "nc6sv3"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = "Standard_NC6s_v3"
  auto_scaling_enabled    = true
  max_count               = 1
  min_count               = 0
  node_count              = 0
  fips_enabled            = false
  host_encryption_enabled = false
  node_labels = {
    "gpu"                  = "nvidia-v100"
    "gpu-count"            = "1"
    "radix-node-gpu"       = "nvidia-v100"
    "radix-node-gpu-count" = "1"
    "sku"                  = "gpu"
  }
  node_public_ip_enabled = false
  node_taints = [
    "radix-node-gpu-count=1:NoSchedule"
  ]
  os_disk_type     = "Ephemeral"
  tags             = {}
  vnet_subnet_id   = var.subnet_id
  workload_runtime = "OCIContainer"
  zones            = []
  depends_on = [ azurerm_kubernetes_cluster.this ]
}

resource "azurerm_kubernetes_cluster_node_pool" "armpipepool" {
  name                    = "armpipepool"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = "Standard_B4ps_v2"
  auto_scaling_enabled    = true
  max_count               = 4
  min_count               = 1
  #node_count              = 1
  fips_enabled            = false
  host_encryption_enabled = false
  node_labels = {
    "nodepooltasks"        = "jobs"
  }
  node_public_ip_enabled = false
  node_taints = [
    "nodepooltasks=jobs:NoSchedule"
  ]
  os_disk_type     = "Managed"
  tags             = {}
  vnet_subnet_id   = var.subnet_id
  workload_runtime = "OCIContainer"
  zones            = []
  depends_on = [ azurerm_kubernetes_cluster.this ]
}

resource "azurerm_kubernetes_cluster_node_pool" "armuserpool" {
  name                    = "armuserpool"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = "Standard_B4ps_v2"
  auto_scaling_enabled    = true
  max_count               = 4
  min_count               = 1
  #node_count              = 1
  fips_enabled            = false
  host_encryption_enabled = false
  node_public_ip_enabled = false
  os_disk_type     = "Managed"
  tags             = {}
  vnet_subnet_id   = var.subnet_id
  workload_runtime = "OCIContainer"
  zones            = []
  depends_on = [ azurerm_kubernetes_cluster.this ]
}

resource "azurerm_kubernetes_cluster_node_pool" "x86pipepool" {
  name                    = "x86pipepool"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = "Standard_B4as_v2"
  auto_scaling_enabled    = true
  max_count               = 4
  min_count               = 1
  #node_count              = 1
  fips_enabled            = false
  host_encryption_enabled = false
  node_labels = {
    "nodepooltasks"        = "jobs"
  }
  node_public_ip_enabled = false
  node_taints = [
    "nodepooltasks=jobs:NoSchedule"
  ]
  os_disk_type     = "Managed"
  tags             = {}
  vnet_subnet_id   = var.subnet_id
  workload_runtime = "OCIContainer"
  zones            = []
  depends_on = [ azurerm_kubernetes_cluster.this ]
}

resource "azurerm_kubernetes_cluster_node_pool" "x86userpool" {
  name                    = "x86userpool"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = "Standard_B4as_v2"
  auto_scaling_enabled    = true
  max_count               = 4
  min_count               = 1
  #node_count              = 1
  fips_enabled            = false
  host_encryption_enabled = false
  node_public_ip_enabled = false
  os_disk_type     = "Managed"
  tags             = {}
  vnet_subnet_id   = var.subnet_id
  workload_runtime = "OCIContainer"
  zones            = []
  depends_on = [ azurerm_kubernetes_cluster.this ]
}