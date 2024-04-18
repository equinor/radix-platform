
variable "hub_to_cluster_peering_name" {
  description = "Name of the Peering name."
  type        = string
}

variable "cluster_to_hub_peering_name" {
  description = "Name of the Peering name."
  type        = string
}

variable "cluster_resource_group" {
  description = "Cluster resource group"
  type        = string
}

variable "vnet_cluster_name" {
  description = "VNET cluster name"
  type        = string
}

variable "vnet_cluster_id" {
  description = "VNET id of cluster"
  type        = string
}

variable "vnet_hub_resource_group" {
  description = "VNET hub resource group"
  type        = string
}

variable "vnet_hub_name" {
  description = "VNET hub name"
  type        = string
}

variable "vnet_hub_id" {
  description = "VNET cluster name"
  type        = string
}
