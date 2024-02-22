variable "resource_groups" {
  type    = list(string)
  default = ["common-extmon"]
}

variable "storageaccounts" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    name                     = string
    resource_group_name      = optional(string, "common-extmon")
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
    lifecyclepolicy          = optional(bool, false)
  }))
  default = {
    log = {
      name = "log"
    },
    velero = {
      name            = "velero"
      lifecyclepolicy = true
    }
  }
}