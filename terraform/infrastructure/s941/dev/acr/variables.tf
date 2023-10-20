variable "AZ_RESOURCE_GROUP_COMMON" {
  description = "Resource group name for common"
  type        = string
}

variable "AZ_LOCATION" {
  description = "Azure resource location"
  type        = string
}

variable "RADIX_ENVIRONMENT" {
  description = "Radix Environment"
  type        = string
}

variable "private_link" {
  description = "Subnet connection."
  type = map(object({
    linkname = string
  }))
  default = null
}

variable "vnet_rg_names" {
  type = map(any)
  default = {
    dev        = "cluster-vnet-hub-dev"
  #  playground = "cluster-vnet-hub-playground"
  }
}
