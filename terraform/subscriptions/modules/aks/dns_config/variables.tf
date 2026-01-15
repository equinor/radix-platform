variable "clusters" {
  description = "Map of cluster configurations with IP addresses"
  type = map(object({
    cluster_name      = string
    active_cluster    = bool
    nginx_ip          = optional(string)
    istio_ip          = optional(string)
    dns_wildcard_type = string # "nginx" or "istio"
  }))
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_resource_group" {
  description = "Common resource group name for DNS zones"
  type        = string
}
