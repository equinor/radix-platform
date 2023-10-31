variable "K8S_ENVIROMENTS" {
  description = "A map of cluster enviroments and their resource group"
  type        = map(object({
    name          = string
    resourceGroup = string
  }))
}

variable "AZ_SUBSCRIPTION_SHORTNAME" {
  description = "Subscription shortname"
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "cluster_location" {
  type = map(any)

  default = {
    prod = "northeurope"
    c2   = "westeurope"
  }
}

variable "cluster_rg" {
  type = map(any)

  default = {
    prod = "clusters"
    c2   = "clusters-westeurope"
  }
}

variable "enviroment_condition" {
  type = map(any)

  default = {
    prod = "notcontains"
    c2   = "contains"
  }
}
