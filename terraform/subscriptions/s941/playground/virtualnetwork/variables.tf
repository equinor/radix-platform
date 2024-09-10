variable "resource_groups" {
  type    = list(string)
  default = ["cluster-vnet-hub"]
}

variable "resource_groups_common_temporary" {
  type    = string
  default = "common"
}

variable "private_endpoints" {
  description = "List of private endpoints"
  type = map(object({
    subresourcename   = string
    resource_id       = string
    manual_connection = optional(bool, false)
  }))
  default = {
    psql-s209nlpdevpsql01-playground = {
      subresourcename   = "postgresqlServer"
      resource_id       = "/subscriptions/f63116e3-4460-4b18-9e64-5a58ce7cf837/resourceGroups/S209-NE-NLP-DEV/providers/Microsoft.DBforPostgreSQL/flexibleServers/s209nlpdevpsql01"
      manual_connection = true
    }
    sql-radix-cost-allocation-playground = {
      subresourcename = "sqlServer"
      resource_id     = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/cost-allocation-playground/providers/Microsoft.Sql/servers/sql-radix-cost-allocation-playground"
    }
    sql-radix-vulnerability-scan-playground = {
      subresourcename = "sqlServer"
      resource_id     = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/vulnerability-scan-playground/providers/Microsoft.Sql/servers/sql-radix-vulnerability-scan-playground"
    }
  }
}