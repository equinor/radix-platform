variable "systempool" {
  type = object({
    vm_size   = string
    tags      = optional(map(string))
    min_nodes = number
    max_nodes = number
  })

  default = {
    vm_size = "Standard_B8ms"
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
    armuserpool = {
      vm_size   = "Standard_B8ps_v2"
      min_count = 1
      max_count = 4

    }
    x86userpool = {
      vm_size   = "Standard_B8as_v2"
      min_count = 1
      max_count = 4

    }
  }
}
