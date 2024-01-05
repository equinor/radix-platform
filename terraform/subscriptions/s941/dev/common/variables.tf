variable "resource_groups" {
  type    = list(string)
  default = ["development"]
}

variable "storageaccounts" {
  type = map(object({
    resource_group_name      = optional(string, "s941-development")
    location                 = optional(string, "northeurope")
    account_tier             = optional(string, "Standard")
    account_replication_type = optional(string, "LRS")
    kind                     = optional(string, "StorageV2")
    change_feed_enabled      = optional(bool, false)
    versioning_enabled       = optional(bool, false)
    enable_backup            = optional(bool, false)
    roleassignment           = optional(map(object({ backup = optional(bool, false)})))
    principal_id = optional(string)
  }))
  default = {
    diag = {
      enable_backup = true
      roleassignment = {
        "Storage Account Backup Contributor" = {
          backup = true
        }
      }
    }
  }
}
