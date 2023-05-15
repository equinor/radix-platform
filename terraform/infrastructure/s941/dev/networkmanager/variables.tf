variable "AZ_SUBSCRIPTION_SHORTNAME" {
  description = "Subscription shortname"
  type        = string
}

variable "K8S_ENVIROMENTS" {
  description = "A list of cluster enviroments"
  type        = list(string)
}

variable "vnet_rg_names" {
  type = map(any)
  default = {
    dev        = "cluster-vnet-hub-dev"
    playground = "cluster-vnet-hub-playground"
  }
}
