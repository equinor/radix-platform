variable "subresourcename_dns" {
  type = map(string)
  default = {
    "blob"             = "privatelink.blob.core.windows.net"
    "postgresqlServer" = "privatelink.postgres.database.azure.com"
    "sqlServer"        = "privatelink.database.windows.net"
  }
}

variable "manual_connection" {
  type    = bool
  default = false
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