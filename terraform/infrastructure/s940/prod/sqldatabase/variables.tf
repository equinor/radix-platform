# variable "resource_groups" {
#   type = map(object({
#     name = string
#   }))
#   default = {}
# }

variable "sql_server" {
  type = map(object({
    name    = string
    rg_name = string
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


#   name           = "radix-vulnerability-scan"
#   server_id      = data.azurerm_mssql_server.sql-radix-vulnerability-scan-c2-prod.id
#   collation      = "SQL_Latin1_General_CP1_CI_AS"
#   max_size_gb    = 250
#   read_scale     = false
#   sku_name       = "S0"
#   zone_redundant = false
