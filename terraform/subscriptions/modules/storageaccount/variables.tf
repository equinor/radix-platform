variable "name" {
  description = "Specifies the name of the storage account. Only lowercase Alphanumeric characters allowed"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the storage account"
  type        = string
}

variable "location" {
  description = "Specifies the supported Azure location where the resource exists"
  type        = string
}

variable "environment" {
  description = "A mapping of tags to assign to the resource."
}

variable "tier" {
  description = "Defines the Tier to use for this storage account. Valid options are Standard and Premium"
  type        = string
}

variable "account_replication_type" {
  description = "Defines the type of replication to use for this storage account"
  type        = string
}

variable "kind" {
  description = "Defines the Kind of account"
  type        = string
}

variable "change_feed_enabled" {
  description = "Is the blob service properties for change feed events enabled?"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = " Is versioning enabled?"
  type        = bool
  default     = false
}

variable "change_feed_retention_in_days" {
  description = "The duration of change feed events retention in days"
  type        = number
  default     = 7
}

variable "container_delete_retention_policy" {
  description = "Specifies the number of days that the container should be retained"
  type        = number
  default     = 30
}

variable "delete_retention_policy" {
  description = "Specifies the number of days that the blob should be retained"
  type        = bool
  default     = true
}

variable "backup_center" {
  description = "Specifies the number of days that the blob can be restored. This must be less than the days specified for delete_retention_policy"
  type        = bool
  default     = false
}


variable "principal_id" {
  description = "The ID of the Principal (User, Group or Service Principal) to assign the Role Definition to"
  type        = string
}

# variable "roleassignment" {
#   description = "Other role assignments to be added to this key vault"
#   type = map(object({
#     backup = bool
#   }))
#   default = {}
# }

# variable "backupinstanceblobstorage" {
#   description = "Other role assignments to be added to this key vault"
#   type = map(object({
#     backup = bool
#   }))
#   default = {}
# }

variable "vault_id" {
  description = "The ID of the Backup Vault"
  type        = string
}

variable "policyblobstorage_id" {
  description = "The ID of the Backup Policy."
  type        = string
}

variable "subnet_id" {
  type = string

}

variable "vnethub_resource_group" {
  type = string
}

variable "priv_endpoint" {
  description = "Create private endpoint?"
  type        = bool
  default     = false
}

variable "firewall" {
  description = "Enable FW rules on StorageAccount?"
  type        = bool
  default     = true

}

variable "backup" {
  description = "Enable backup"
  type        = bool
}