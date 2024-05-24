variable "acr" {
  description = "ACR"
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

variable "ip_rule" {
  description = "Allowed IP rule"
  type        = string
}

variable "virtual_network" {
  type    = string
  default = "vnet-hub"
}

variable "vnet_resource_group" {
  type = string
}

variable "subnet_id" {
  description = "A list of virtual network subnet ids to secure the storage account."
  type        = string
}
