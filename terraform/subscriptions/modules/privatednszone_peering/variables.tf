variable "clustervnet" {
  description = "Name of the Cluster."
  type        = string
}

variable "cluster_vnet_resourcegroup" {
  description = "Cluster VNET hub resource group"
  type        = string
}

variable "private_dns_zone" {
  description = "Private DNS Zone name"
  type        = string
}

variable "vnet_cluster_hub_id" {
  description = "Cluster VNET hub name"
  type        = string
}