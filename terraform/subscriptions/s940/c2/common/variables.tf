variable "resource_groups" {
  type    = list(string)
  default = ["common-c2"]
}

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
    firewall                 = optional(bool, true)
  }))
  default = {
    log = {
      name = "log"
      account_replication_type = "ZRS"
      backup = true

    },
    velero = {
      name = "velero"
      account_replication_type = "GRS"
      backup = true
    }
  }
}