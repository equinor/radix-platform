variable "AZ_RESOURCE_GROUP_COMMON" {
  description = "Resource group name for common"
  type        = string
}

variable "AZ_LOCATION" {
  description = "Azure resource location"
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  type = string
}

variable "RADIX_ENVIRONMENT" {
  description = "Radix Environment"
  type        = string
}

variable "private_link" {
  description = "Subnet connection."
  type        = map(object({
    linkname = string
  }))
  default = null
}
variable "virtual_networks" {
  type = map(object({
    rg_name = string
  }))
  default = {
    "dev" = {
      rg_name = "cluster-vnet-hub-dev"
    }
    "playground" = {
      rg_name = "cluster-vnet-hub-playground"
    }
  }
}

variable "AZ_RESOURCE_GROUP_CLUSTERS" {
  type = string
}

variable "K8S_ENVIROMENTS" {
  description = "A list of cluster enviroments"
  type        = list(string)
}
