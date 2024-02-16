# variable "resource_groups" {
#   type    = list(string)
#   default = ["common-platform"]
# }

variable "resource_groups_ver1" {
  description = "Resource groups ver1"
  type = map(object({
    name                 = string
    roleassignment       = optional(bool, false)
    role_definition_name = optional(string, "")
    principal_id         = optional(string, "")

  }))
  default = {
    common-platform = {
      name                 = "common-platform"
      roleassignment       = true
      role_definition_name = "Log Analytics Contributor"
    }
  }

}


variable "storageaccounts" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    name                     = string
    resource_group_name      = optional(string, "common-platform")
    location                 = optional(string, "northeurope")
    account_tier             = optional(string, "Standard")
    account_replication_type = optional(string, "LRS")
    kind                     = optional(string, "StorageV2")
    velero_service_principal = optional(string, "radix-velero-prod")
    change_feed_enabled      = optional(bool, false)
    versioning_enabled       = optional(bool, false)
    backup                   = optional(bool, false)
    principal_id             = optional(string)
    private_endpoint         = optional(bool, false)
  }))
  default = {
    log = {
      name                     = "log"
      account_replication_type = "ZRS"
      backup                   = true

    },
    velero = {
      name                     = "velero"
      account_replication_type = "GRS"
      backup                   = true
    }
  }
}