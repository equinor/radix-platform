variable "aksclusters" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    autostartupschedule       = optional(bool, "false")
    migrationStrategy         = optional(string, "aa")
    outbound_ip_address_ids   = list(string)
    node_os_upgrade_channel   = optional(string, "None")
    ip                        = string
    subnet_id                 = string
    aksversion                = optional(string, "1.29.2")
    cost_analysis             = optional(bool, "false")
    dns_prefix                = optional(string)
    clustertags               = optional(map(string))
    workload_identity_enabled = optional(bool, "false")
    network_policy            = optional(string, "calico") #Currently supported values are calico, azure and cilium
  }))
  default = {
    eu-18 = {
      outbound_ip_address_ids = ["/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-001", "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-002", "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-003", "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-004", "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-005", "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-006", "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-007", "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-production-northeurope-008"]
      subnet_id               = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/clusters/providers/Microsoft.Network/virtualNetworks/vnet-eu-18/subnets/subnet-eu-18"
      ip                      = "10.8.0.0"
      cost_analysis           = false
      clustertags = {
        "migrationStrategy" = "aa"
      }
    }
  }
}

variable "systempool" {
  type = object({
    vm_size   = string
    tags      = optional(map(string))
    min_nodes = number
    max_nodes = number
  })

  default = {
    vm_size = "Standard_E16as_v4"
    tags = {
      "nodepool" = "systempool"
    }
    min_nodes = 3
    max_nodes = 4
  }
}

variable "nodepools" {
  type = map(object({
    vm_size      = string
    min_count    = number
    max_count    = number
    node_count   = optional(number, 1)
    node_labels  = optional(map(string))
    node_taints  = optional(list(string), [])
    os_disk_type = optional(string, "Managed")
  }))
  default = {
    nc24sv3 = {
      vm_size    = "Standard_NC24s_v3"
      min_count  = 0
      max_count  = 1
      node_count = 0
      node_labels = {
        "gpu"                  = "nvidia-v100"
        "gpu-count"            = "4"
        "radix-node-gpu"       = "nvidia-v100"
        "radix-node-gpu-count" = "4"
        "sku"                  = "gpu"
      }
      node_taints  = ["radix-node-gpu-count=4:NoSchedule"]
      os_disk_type = "Ephemeral"
    }
    nc12sv3 = {
      vm_size    = "Standard_NC12s_v3"
      min_count  = 0
      max_count  = 1
      node_count = 0
      node_labels = {
        "gpu"                  = "nvidia-v100"
        "gpu-count"            = "2"
        "radix-node-gpu"       = "nvidia-v100"
        "radix-node-gpu-count" = "2"
        "sku"                  = "gpu"
      }
      node_taints  = ["radix-node-gpu-count=2:NoSchedule"]
      os_disk_type = "Ephemeral"
    }
    nc6sv3 = {
      vm_size    = "Standard_NC6s_v3"
      min_count  = 0
      max_count  = 1
      node_count = 0
      node_labels = {
        "gpu"                  = "nvidia-v100"
        "gpu-count"            = "1"
        "radix-node-gpu"       = "nvidia-v100"
        "radix-node-gpu-count" = "1"
        "sku"                  = "gpu"
      }
      node_taints  = ["radix-node-gpu-count=1:NoSchedule"]
      os_disk_type = "Ephemeral"

    }
    armpipepool = {
      vm_size   = "Standard_E16ps_v5"
      min_count = 1
      max_count = 16
      node_labels = {
        "nodepooltasks" = "jobs"
      }
      node_taints = ["nodepooltasks=jobs:NoSchedule"]
    }
    armuserpool = {
      vm_size   = "Standard_E16ps_v5"
      min_count = 1
      max_count = 17

    }
    x86pipepool = {
      vm_size   = "Standard_E16as_v5"
      min_count = 1
      max_count = 16
      node_labels = {
        "nodepooltasks" = "jobs"
      }
      node_taints = ["nodepooltasks=jobs:NoSchedule"]

    }
    x86userpool = {
      vm_size   = "Standard_E16as_v5"
      min_count = 16
      max_count = 60

    }
    monitorpool = {
      vm_size   = "Standard_E20ps_v5"
      min_count = 1
      max_count = 2
      node_labels = {
        "nodepooltasks" = "monitor"
      }
      node_taints = ["nodetasks=monitor:NoSchedule"]

    }
  }
}

variable "authorized_ip_ranges" {
  type = list(string)
  default = ["143.97.110.1/32",
    "143.97.2.129/32",
    "143.97.2.35/32",
    "8.29.230.8/32",
    "92.221.25.155/32",
  "92.221.72.153/32"]
}