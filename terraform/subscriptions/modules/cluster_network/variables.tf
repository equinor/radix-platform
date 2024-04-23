variable "cluster_name" {
  description = "Name of the Peering name."
  type        = string
}

variable "location" {
  description = "The Azure Region where the Backup Vault should exist."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group where the Backup Vault should exist"
  type        = string
}