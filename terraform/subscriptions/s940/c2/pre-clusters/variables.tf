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
    vm_size         = string
    min_count       = number
    max_count       = number
    node_count      = optional(number, 1)
    node_labels     = optional(map(string))
    node_taints     = optional(list(string), [])
    os_disk_type    = optional(string, "Managed")
    nodepool_os_sku = optional(string, "Ubuntu")
  }))
  default = {
    memory2v1 = {
      vm_size    = "Standard_M96s_2_v3"
      min_count  = 0
      max_count  = 2
      node_count = 0
      node_labels = {
        "radix-nodetype" = "memory-optimized-2-v1"
      }
      node_taints = ["radix-nodetype=memory-optimized-2-v1:NoSchedule"]
    }
    nvidia1v1 = {
      vm_size    = "Standard_NV12ads_A10_v5"
      min_count  = 0
      max_count  = 1
      node_count = 0
      node_labels = {
        "radix-nodetype" = "gpu-nvidia-1-v1"
      }
      node_taints  = ["radix-nodetype=gpu-nvidia-1-v1:NoSchedule"]
      os_disk_type = "Ephemeral"
    }
    nc6sv3 = {
      vm_size    = "Standard_NV12ads_A10_v5"
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
      max_count = 8
      node_labels = {
        "nodepooltasks" = "jobs"
      }
      node_taints = ["nodepooltasks=jobs:NoSchedule"]
    }
    armuserpool = {
      vm_size   = "Standard_E16ps_v5"
      min_count = 1
      max_count = 16

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
      min_count = 3
      max_count = 16

    }
  }
}
