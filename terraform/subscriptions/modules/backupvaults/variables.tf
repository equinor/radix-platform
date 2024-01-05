variable "name" {
  description = "Specifies the name of the Backup Vault"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group where the Backup Vault should exist"
}

variable "location" {
  description = "The Azure Region where the Backup Vault should exist."
}

variable "policyblobstoragename" {
  description = "he name which should be used for this Backup Policy Blob Storage."

}