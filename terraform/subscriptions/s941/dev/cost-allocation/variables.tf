variable "admin-adgroup" {
  type    = string
  default = "Radix SQL server admin - dev"
}

variable "resourse_group_name" {
  type    = string
  default = "cost-allocation"
}

variable "keyvault_dbadmin_secret_name" {
  type    = string
  default = "radix-cost-allocation-db-admin"
}
