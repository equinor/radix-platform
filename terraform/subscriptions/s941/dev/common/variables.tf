variable "resource_groups" {
  type    = list(string)
  default = ["common-dev"]
}

# roleassignment = {"Storage Account Backup Contributor" = { backup = false }}
#roleassignment = { "Storage Account Backup Contributor" = { backup = true }}


variable "storageaccounts" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    name                     = string
    resource_group_name      = optional(string, "common-dev")
    location                 = optional(string, "northeurope")
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
    },
    velero = {
      name = "velero"
    }
  }
}

#Template
# template = {
#     name = "log"
#     roleassignment = {
#       "Storage Account Backup Contributor" = {
#         backup = true
#       }
#     }
#     }
