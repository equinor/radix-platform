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
    roleassignment           = optional(map(object({ backup = optional(bool, false) })))
    #roleassignment          = optional(map(object({ roleassignment = { "Storage Account Backup Contributor" = { backup = optional(bool, true) }} })))
    principal_id             = optional(string)
    private_endpoint         = optional(bool, false)
    firewall                 = optional(bool, true)
  }))
  default = {
    diagnostics = {
      name = "diagnostics"
      # roleassignment = {
      #   "Storage Account Backup Contributor" = {
      #     backup = true
      #   }
      # }
    }
    # terraform = {
    #   name                     = "terraform"
    #   account_replication_type = "RAGRS"
    #   private_endpoint         = true
    #   roleassignment = {
    #     "Storage Account Backup Contributor" = {
    #       backup = true
    #     }
    #   }
    # }
  }
}
