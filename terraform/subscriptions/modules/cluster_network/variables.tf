variable "cluster_name" {
  description = "Name of the Peering name."
  type        = string
}

variable "location" {
  description = "The Azure Region"
  type        = string
}

variable "resource_group_name" {
  description = "The Resource Group"
  type        = string
}

variable "storageaccount_id" {
  description = "The ID of the Storage Account"
  type        = string
}

variable "address_space" {
  description = "Address space"
  type        = string
}

variable "enviroment" {
  description = "Enviroment"
  type        = string
}