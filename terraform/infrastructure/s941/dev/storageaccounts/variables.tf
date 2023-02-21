variable "AZ_LOCATION" {
  description = "The location to create the resources in."
  type        = string
}

variable "AZ_RESOURCE_GROUP_COMMON" {
  description = "Resource group name for common"
  type        = string
}

variable "RADIX_ZONE" {
  description = "Radix zone"
  type        = string
}

variable "storage_accounts" {
  type = map(object({
    name                              = string                          # Mandatory
    rg_name                           = string                          # Mandatory
    location                          = optional(string, "northeurope") # Optional
    kind                              = optional(string, "StorageV2")   # Optional
    repl                              = optional(string, "LRS")         # Optional
    tier                              = optional(string, "Standard")    # Optional
    backup_center                     = optional(bool, false)           # Optional      
    life_cycle                        = optional(bool, true)
    firewall                          = optional(bool, true)
    container_delete_retention_policy = optional(bool, true)
    tags                              = optional(map(string), {})
    allow_nested_items_to_be_public   = optional(bool, false) #GUI: Configuration | Allow Blob public access
    shared_access_key_enabled         = optional(bool, true)
    cross_tenant_replication_enabled  = optional(bool, true)
    delete_retention_policy           = optional(bool, true)
    versioning_enabled                = optional(bool, true)
    change_feed_enabled               = optional(bool, true)
    change_feed_days                  = optional(number, 35)
    skip_creation                     = optional(bool, false)
  }))
  default = {}
}
