variable "subresourcename_dns" {
  type = map(string)
  default = {
    "blob"                = "privatelink.blob.core.windows.net"
    "configurationStores" = "privatelink.azconfig.io"
    "coordinator"         = "privatelink.postgres.cosmos.azure.com"
    "mysqlServer"         = "privatelink.mysql.database.azure.com"
    "postgresqlServer"    = "privatelink.postgres.database.azure.com"
    "privatelinkservice"  = "privatelink.radix.equinor.com"
    "redisCache"          = "privatelink.redis.cache.windows.net"
    "Sql"                 = "privatelink.documents.azure.com"
    "sqlServer"           = "privatelink.database.windows.net"
    "table"               = "privatelink.table.core.windows.net"
    "vault"               = "privatelink.vaultcore.azure.net"
  }
}

variable "virtual_network" {
  type    = string
  default = "vnet-hub"
}

variable "vnet_resource_group" {
  type = string
}

variable "server_name" {
  type = string
}

variable "location" {
  default = "northeurope"
  type    = string
}

variable "resource_id" {
  type = string
}

variable "subresourcename" {
  type = string
}

variable "customdnszone" {
  type = string
  default = ""
}