variable "resource_groups" {
  type    = list(string)
  default = ["cluster-vnet-hub"]
}

variable "resource_groups_common_temporary" {
  type    = string
  default = "common-westeurope"
}
