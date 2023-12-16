variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "mysql_flexible_server" {
  type = map(object({
    name                  = string
    rg_name               = optional(string, "monitoring")
    location              = optional(string, "northeurope")
    administrator_login   = optional(string, "radixadmin")
    backup_retention_days = optional(number, 7)
    sku_name              = optional(string, "B_Standard_B1ms")
    version               = optional(string, "5.7")
    zone                  = optional(number, 2)
    secret                = string
    vault                 = optional(string, "radix-monitoring-dev-dr") # Vault that keeps the secret
  }))
  default = {}
}

variable "mysql_server" {
  description = "Legacy Mysql servers"
  type = map(object({
    name                             = string
    rg_name                          = optional(string, "monitoring")
    location                         = optional(string, "northeurope")
    administrator_login              = optional(string, "radixadmin")
    sku_name                         = optional(string, "B_Gen5_1")
    version                          = optional(string, "5.7")
    ssl_minimal_tls_version_enforced = optional(string, "TLSEnforcementDisabled")
    storage_mb                       = optional(number, 102400)
    tags                             = optional(map(string), {})
    secret                           = string
    vault                            = optional(string, "radix-monitoring-dev-dr") # Vault that keeps the secret
  }))
  default = {}
}

variable "firewall_rules" {
  description = "Range of IP addresses to allow firewall connections."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = null
}

variable "key_vault" {
  description = "Name of Keyvault."
  type = map(object({
    name    = string
    rg_name = string
  }))
  default = {}
}
