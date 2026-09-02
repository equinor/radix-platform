variable "systempool" {
  type = object({
    vm_size   = string
    tags      = optional(map(string))
    min_nodes = number
    max_nodes = number
    os_sku    = optional(string, "AzureLinux")
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
    vm_size                       = string
    min_count                     = number
    max_count                     = number
    node_count                    = optional(number, 1)
    node_labels                   = optional(map(string))
    node_taints                   = optional(list(string), [])
    os_disk_type                  = optional(string, "Managed")
    nodepool_os_sku               = optional(string, "AzureLinux")
    max_surge                     = optional(string, "33%")
    drain_timeout_in_minutes      = optional(number, 1440)
    node_soak_duration_in_minutes = optional(number, 10)
  }))
  default = {
    armuserpool = {
      vm_size   = "Standard_B8ps_v2"
      min_count = 1
      max_count = 4

    }
    x86userpool = {
      vm_size                       = "Standard_B8as_v2"
      min_count                     = 1
      max_count                     = 4
      max_surge                     = "5"
      node_soak_duration_in_minutes = 10
    }
  }
}
