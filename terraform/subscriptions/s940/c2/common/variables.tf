variable "storageaccounts" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    name                     = string
    resource_group_name      = optional(string, "common-c2")
    location                 = optional(string, "westeurope")
    account_tier             = optional(string, "Standard")
    account_replication_type = optional(string, "LRS")
    kind                     = optional(string, "StorageV2")
    change_feed_enabled      = optional(bool, false)
    versioning_enabled       = optional(bool, false)
    backup                   = optional(bool, false)
    principal_id             = optional(string)
    private_endpoint         = optional(bool, false)
    lifecyclepolicy          = optional(bool, false)
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
      lifecyclepolicy          = true
    }
  }
}

variable "resource_groups_common_temporary" {
  type    = string
  default = "common-westeurope"
}