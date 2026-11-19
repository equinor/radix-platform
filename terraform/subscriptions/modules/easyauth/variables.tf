variable "location" {
  type = string
}

variable "resource_group_name" {
  description = "Resource group for the Dex identity and the Postgres server."
  type        = string
}

variable "vnet_resource_group" {
  description = "Resource group of vnet-hub and the private DNS zones."
  type        = string
}

variable "app_display_name" {
  type = string
}

variable "dex_mi_name" {
  description = "Managed identity name for Dex."
  type        = string
}

variable "postgres_server_name" {
  description = "Name of the Postgres flexible server."
  type        = string
}

variable "app_owners" {
  description = "Object IDs of the app registration owners."
  type        = list(string)
}

variable "allowed_group_objectids" {
  description = "Groups assigned to the app registration. Only members can sign in."
  type        = list(string)
}

variable "postgres_admin_group_name" {
  description = "Entra group made Postgres administrator."
  type        = string
}

variable "postgres_sku_name" {
  description = "Postgres flexible server SKU, e.g. B_Standard_B1ms."
  type        = string
}

variable "postgres_version" {
  description = "Postgres major version, e.g. 17."
  type        = string
}

variable "postgres_storage_mb" {
  description = "Initial Postgres storage in MB. Storage grows automatically."
  type        = number
}
