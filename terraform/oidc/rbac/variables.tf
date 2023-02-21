variable "AAD_RADIX_GROUP" {
  description = "Radix group name"
  type        = string
}

variable "APP_GITHUB_ACTION_CLUSTER_NAME" {
  description = "Application name"
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}
variable "GH_ORGANIZATION" {
  description = "Github organization"
  type        = string
}

variable "GH_REPOSITORY" {
  description = "Github repository"
  type        = string
}

variable "GH_ENVIRONMENT" {
  description = "Github environment"
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
    create_with_rbac                  = optional(bool, false)
  }))
  default = {}
}
