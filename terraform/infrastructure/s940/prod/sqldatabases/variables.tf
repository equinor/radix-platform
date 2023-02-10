variable "AZ_LOCATION" {
  description = "The location to create the resources in."
  type        = string
}

variable "AZ_RESOURCE_GROUP_COMMON" {
  description = "Resource group name for common(platorm)"
  type        = string
}

variable "RADIX_ZONE" {
  description = "Radix zone"
  type        = string
}

variable "identity" {
  description = "The identity to configure for this SQL Server."

  type = object({
    type         = optional(string, "SystemAssigned")
    identity_ids = optional(list(string), [])
  })

  default = null
}


variable "sql_server" {
  type = map(object({
    administrator_login           = optional(string, "radix")
    location                      = optional(string, "northeurope")
    minimum_tls_version           = optional(string, "1.2")
    name                          = string
    rg_name                       = string
    tags                          = optional(map(string), {})
    version                       = optional(string, "12.0")
    azuread_administrator         = optional(object({
      azuread_authentication_only = optional(bool, false)
    }), {})
    identity = optional(bool, true)
    db_admin                      = string  # Used in azurerm_key_vault_secret
  }))
  default = {}
}

variable "sql_database" {
  type = map(object({
    name           = string
    server         = string
    collation      = optional(string, "SQL_Latin1_General_CP1_CI_AS")
    max_size_gb    = optional(number, 250)
    read_scale     = optional(bool, false)
    sku_name       = optional(string, "S3")
    zone_redundant = optional(bool, false)
    tags           = optional(map(string), {})
  }))
  default = {}
}

variable "key_vault" {
  type = map(object({
    name            = string
    rg_name         = string
  }))
  default = {}
}

variable "key_secrets" {
  type = map(object({
    name            = string
    vault         = string
  }))
  default = {}
}
