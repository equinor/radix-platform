variable "resource_group_name" {
  description = "The name of the resource group in which to create the Public IP Prefix"
  type = string
}

variable "publicipprefixname" {
  description = "Specifies the name of the Public IP Prefix resource"
  type = string
}

variable "location" {
  description = "Specifies the supported Azure location where the resource exists."
  type = string
}

variable "zones" {
  description = "Specifies a list of Availability Zones in which this Public IP Prefix should be located."
  type = list(string)
  default = []
}