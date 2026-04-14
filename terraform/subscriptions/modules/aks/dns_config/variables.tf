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

variable "zone_name" {
  description = "DNS zone name used for wildcard records"
  type        = string
}

variable "dns_resource_group" {
  description = "Resource group for DNS A records that are not always in the common resource group"
  type        = string
}

variable "create_active_records" {
  description = "Whether to create active wildcard records (@, *, *.app)"
  type        = bool
  default     = true
}
