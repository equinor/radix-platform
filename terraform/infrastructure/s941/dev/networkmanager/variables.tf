variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "AZ_SUBSCRIPTION_SHORTNAME" {
  description = "Subscription shortname"
  type        = string
}

variable "AZ_LOCATION" {
  description = "Azure location"
  type        = string
}

variable "K8S_ENVIROMENTS" {
  description = "A map of cluster enviroments and their resource group"
  type = map(object({
    name          = string
    resourceGroup = string
  }))
}

variable "vnet_rg_names" {
  type = map(any)
  default = {
    dev        = "cluster-vnet-hub-dev"
    playground = "cluster-vnet-hub-playground"
  }
}

variable "cluster_rg" {
  type = map(any)

  default = {
    dev        = "clusters"
    playground = "clusters"
  }
}

variable "cluster_location" {
  type = map(any)

  default = {
    dev        = "northeurope"
    playground = "northeurope"
  }
}

variable "enviroment_condition" {
  type = map(any)

  default = {
    dev        = "notcontains"
    playground = "contains"
  }
}
