variable "administrator_login" {
  default = "radix"
  type    = string
}

variable "location" {
  default = "northeurope"
  type    = string
}

variable "server_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "zone" {
  type    = number
  default = 2
}

variable "backup_retention_days" {
  type    = number
  default = 14
}

variable "geo_redundant_backup_enabled" {
  type    = bool
  default = true
}

variable "sku_name" {
  type = string
}

variable "mysql_version" {
  type = number
}

variable "identity_ids" {
  type = string
}

variable "sql_admin_display_name" {
  type = string
}

variable "database_name" {
  type = string
}

variable "vnet_resource_group" {
  type = string
}

variable "virtual_network" {
  type    = string
  default = "vnet-hub"
}

variable "generate_invisible_primary" {
  type    = string
  default = "Off"
}