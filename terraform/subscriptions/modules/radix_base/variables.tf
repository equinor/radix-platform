variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_resource_group" {
  type = string
}

variable "common_resource_group" {
  type = string
}

variable "cluster_resource_group" {
  type = string
}

variable "subscription_shortname" {
  type = string
}

variable "cluster_type" {
  type = string
}

variable "testzone" {
  type    = bool
  default = false
}

variable "private_dns_zones_names" {
  type = list(string)
  
}

variable "secondary_location" {
  type = string
}

variable "key_vault_name" {
  type = string
}

variable "storageaccounts" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    name                     = string
    resource_group_name      = string
    location                 = string
    account_tier             = string
    account_replication_type = string
    kind                     = string
    change_feed_enabled      = bool
    versioning_enabled       = bool
    backup                   = bool
    principal_id             = optional(string)
    private_endpoint         = bool
    lifecyclepolicy          = bool
  }))
}

variable "radix_cr_cicd" {
  type = string
}