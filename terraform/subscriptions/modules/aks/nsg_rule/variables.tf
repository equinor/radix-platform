variable "nsg_ids" {
  description = "Map of NSG names to IDs"
  type        = map(string)
}

variable "resource_group_name" {
  description = "Resource group name where NSGs and Public IPs are located"
  type        = string
}

variable "clusters" {
  description = "Map of cluster configurations"
  type = map(object({
    networkset = string
  }))
}

variable "networksets" {
  description = "Map of networkset configurations"
  type = map(object({
    ingressIP  = optional(string)
    gatewayPIP = optional(string)
  }))
}
