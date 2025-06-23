
variable "common_resource_group" {
  type = string
}

variable "vnet_resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "developers" {
  type = list(string)

}

variable "subscription" {
  type = string
}

variable "private_dns_zones_names" {
  type = list(string)

}

variable "cluster_name" {
  type = string
}

variable "cluster_resource_group" {
  type = string

}

variable "dns_prefix" {
  type = string
}

variable "outbound_ip_address_ids" {
  type = list(string)
}

variable "address_space" {
  type = string
}

variable "aks_version" {
  type = string
}

variable "network_policy" {
  type    = string
  default = "cilium"
}

variable "ingressIP" {
  type = string
}

variable "systempool" {
  type = object({
    vm_size   = string
    tags      = optional(map(string))
    min_nodes = number
    max_nodes = number
  })
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
}
