variable "sql_server" {
  type = map(object({
    administrator_login = optional(string, "radix")
    location            = optional(string, "northeurope")
    minimum_tls_version = optional(string, "1.2")
    name                = string
    rg_name             = string
    tags                = optional(map(string), {})
    version             = optional(string, "12.0")
    azuread_administrator = optional(object({
      azuread_authentication_only = optional(bool, false)
    }), {})
    identity = optional(bool, true)
    db_admin = string # Used in azurerm_key_vault_secret
    vault    = string
    env      = string
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
    sku_name       = optional(string, "S0")
    zone_redundant = optional(bool, false)
    tags           = optional(map(string), {})
  }))
  default = {}
}

variable "key_vault" {
  type = map(object({
    name    = string
    rg_name = string
  }))
  default = {}
}

variable "virtual_networks" {
  type = map(object({
    name    = optional(string, "vnet-hub")
    rg_name = string
  }))
  default = {}
}