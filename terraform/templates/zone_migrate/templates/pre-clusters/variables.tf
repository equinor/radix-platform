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
