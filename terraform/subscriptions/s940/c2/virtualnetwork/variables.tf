variable "resource_groups" {
  type    = list(string)
  default = ["cluster-vnet-hub"]
}

variable "resource_groups_common_temporary" {
  type    = string
  default = "common-westeurope"
}

variable "private_endpoints" {
  description = "List of private endpoints"
  type = map(object({
    subresourcename   = string
    resource_id       = string
    manual_connection = optional(bool, false)
  }))
  default = {
    sql-radix-cost-allocation-c2 = {
      subresourcename = "sqlServer"
      resource_id     = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/cost-allocation-c2/providers/Microsoft.Sql/servers/sql-radix-cost-allocation-c2"
    }
    sql-radix-vulnerability-scan-c2 = {
      subresourcename = "sqlServer"
      resource_id     = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/vulnerability-scan-c2/providers/Microsoft.Sql/servers/sql-radix-vulnerability-scan-c2"
    }
  }
}