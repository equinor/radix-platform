variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "AZ_SUBSCRIPTION_SHORTNAME" {
  description = "Subscription shortname"
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
    prod = "cluster-vnet-hub-prod"
    c2   = "cluster-vnet-hub-c2"
  }
}
