variable "systempool" {
  type = object({
    vm_size   = string
    tags      = optional(map(string))
    min_nodes = number
    max_nodes = number
  })

  default = {
    vm_size = "Standard_B4as_v2"
    tags = {
      "nodepool" = "systempool"
    }
    min_nodes = 2
    max_nodes = 3
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
      vm_size   = "Standard_B4ps_v2"
      min_count = 1
      max_count = 4
      node_labels = {
        "nodepooltasks" = "jobs"
      }
      node_taints = ["nodepooltasks=jobs:NoSchedule"]
    }
    armuserpool = {
      vm_size   = "Standard_B4ps_v2"
      min_count = 1
      max_count = 4

    }
    x86pipepool = {
      vm_size   = "Standard_B4as_v2"
      min_count = 1
      max_count = 4
      node_labels = {
        "nodepooltasks" = "jobs"
      }
      node_taints = ["nodepooltasks=jobs:NoSchedule"]

    }
    x86userpool = {
      vm_size   = "Standard_B4as_v2"
      min_count = 1
      max_count = 4
    }
  }
}
