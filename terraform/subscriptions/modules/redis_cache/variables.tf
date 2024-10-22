variable "name" {
  description = "Name of the Redis Cache."
  type        = string
}

variable "location" {
  default = "northeurope"
  type    = string
}

variable "rg_name" {
  type = string
}

variable "sku_name" {
  default = "Basic"
  type    = string
}

variable "vnet_resource_group" {
  type = string
}

variable "virtual_network" {
  type    = string
  default = "vnet-hub"
}