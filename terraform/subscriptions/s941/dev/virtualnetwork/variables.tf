variable "resource_groups" {
  type    = list(string)
  default = ["cluster-vnet-hub"]
}

variable "enviroment_temporary" {
  type    = string
  default = "development"
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
    radixblobtest6 = {
      subresourcename   = "blob"
      resource_id       = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/test-resources/providers/Microsoft.Storage/storageAccounts/radixblobtest6"
      manual_connection = true
    }
    sql-radix-cost-allocation-dev = {
      subresourcename = "sqlServer"
      resource_id     = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/cost-allocation-dev/providers/Microsoft.Sql/servers/sql-radix-cost-allocation-dev"
    }
    sql-radix-vulnerability-scan-dev = {
      subresourcename = "sqlServer"
      resource_id     = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/vulnerability-scan-dev/providers/Microsoft.Sql/servers/sql-radix-vulnerability-scan-dev"
    }
  }
}