variable "administrator_login" {
  default = "radix"
  type    = string
}
variable "administrator_password" {
  type = string
}
variable "admin_adgroup" {
  type = string
}
variable "location" {
  default = "northeurope"
  type    = string
}
variable "minimum_tls_version" {
  default = "1.2"
  type    = string
}
variable "server_name" {
  type = string
}
variable "rg_name" {
  type = string
}
variable "server_version" {
  default = "12.0"
  type    = string
}
variable "public_network_access_enabled" {
  default = false
  type    = bool
}
variable "azuread_authentication_only" {
  default = false
  type    = bool
}
variable "env" {
  type        = string
  description = "dev, playground, c2 or prod"
}


variable "database_name" {
  type = string
}
variable "collation" {
  type    = string
  default = "SQL_Latin1_General_CP1_CI_AS"
}
variable "max_size_gb" {
  type    = number
  default = 250
}
variable "read_scale" {
  type    = bool
  default = false
}
variable "sku_name" {
  type    = string
  default = "S0"
}
variable "zone_redundant" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "database_tags" {
  type    = map(string)
  default = {}
}

variable "virtual_network" {
  type    = string
  default = "vnet-hub"
}

variable "admin_federated_credentials" {
  type = map(object({
    issuer  = string
    subject = string
  }))
}
