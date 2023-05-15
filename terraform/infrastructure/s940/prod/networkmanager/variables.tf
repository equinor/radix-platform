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
    prod = "cluster-vnet-hub-prod"
    c2   = "radix-private-links-c2-prod"
  }
}
