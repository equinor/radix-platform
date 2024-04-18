variable "enviroment" {
  description = "Name of the Enviroment."
  type        = string
}

variable "location" {
  description = "The location/region where the virtual network is created"
  type        = string
}

variable "vnet_resource_group" {
  description = "VNET resource group"
  type        = string
}

variable "private_dns_zones" {
  description = "Private DNS zones"
  type        = list(string)
}