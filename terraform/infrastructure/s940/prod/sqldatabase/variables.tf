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
