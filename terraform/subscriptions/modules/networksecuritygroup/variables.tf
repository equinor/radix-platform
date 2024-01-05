variable "resource_group_name" {
  description = "The name of the resource group in which to create the network security group"
  type        = string
}

variable "location" {
  description = "Specifies the supported Azure location where the resource exists"
  type        = string
}

variable "networksecuritygroupname" {
  description = "Specifies the name of the network security group"
  type        = string
}

variable "destination_address_prefix" {
  description = "List of destination address prefixes."
  type        = string
}