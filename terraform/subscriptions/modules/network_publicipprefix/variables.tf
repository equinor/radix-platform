variable "resource_group_name" {
  description = "The name of the resource group in which to create the Public IP Prefix"
  type        = string
}

variable "publicipprefixname" {
  description = "Specifies the name of the Public IP Prefix resource"
  type        = string
}

variable "pipprefix" {
  description = "Specifies the name of the Public IP name"
  type        = string
}

variable "pippostfix" {
  description = "Specifies the name of the Public IP name"
  type        = string
}

variable "enviroment" {
  description = "Specifies the name of the Public IP name"
  type        = string
}

variable "location" {
  description = "Specifies the supported Azure location where the resource exists."
  type        = string
}

variable "zones" {
  description = "Specifies a list of Availability Zones in which this Public IP Prefix should be located."
  type        = list(string)
  default     = []
}

variable "prefix_length" {
  description = "Size of IP Prefix"
  type        = number
  default     = 30
}

variable "publicipcounter" {
  description = "Count number of public ip's (4 or 8)"
  type        = number
  default     = 4
}

variable "puplicipstartcounter" {
  type    = number
  default = 1
}

variable "testzone" {
  type    = bool
  default = false
}