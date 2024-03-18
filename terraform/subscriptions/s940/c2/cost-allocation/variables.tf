variable "admin-adgroup" {
  type    = string
  default = "Radix SQL server admin - c2"
}

variable "keyvault_dbadmin_secret_name" {
  type    = string
  default = "radix-cost-allocation-db-admin"
}

variable "acr_name" {
  type    = string
  default = "radixc2prod"
}
