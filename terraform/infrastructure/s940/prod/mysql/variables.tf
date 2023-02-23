variable "mysql_flexible_server" {
  type = map(object({
    name                  = string
    rg_name               = optional(string, "monitoring")
    location              = optional(string, "northeurope")
    administrator_login   = optional(string, "radixadmin")
    backup_retention_days = optional(number, 35)
    sku_name              = optional(string, "B_Standard_B2ms")
    version               = optional(string, "5.7")
    zone                  = optional(number, 2)
    secret                = string
    vault                 = optional(string, "kv-radix-monitoring-prod") # Vault that keeps the secret
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
    vault                            = optional(string, "kv-radix-monitoring-prod") # Vault that keeps the secret
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

variable "key_secrets" {
  description = "Name of secrets in a Keyvault."
  type = map(object({
    name  = optional(string, "grafana-database-password")
    vault = optional(string, "radix-vault-dev")
  }))
  default = null
}
