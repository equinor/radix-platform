# variable "tenant_id" {
#   description = "Tenant ID"
#   type        = string
# }

# variable "subscription_id" {
#   description = "The subscription ID"
#   type        = string
# }

variable "vault_name" {
  description = "The name of this Key vault."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to create the resources in."
  type        = string
}

variable "location" {
  description = "The location to create the resources in."
  type        = string
}

variable "soft_delete_retention_days" {
  type    = number
  default = 90
}

variable "purge_protection_enabled" {
  description = "Is purge protection enabled for this Key vault?"
  type        = bool
  default     = true
}

variable "enable_rbac_authorization" {
  description = "Should RBAC authorization be enabled for this Key vault?"
  type        = bool
  default     = true
}

variable "kv_secrets_user_id" {
  description = "The ID of the App that got Key Vault Secrets user permission?"
  type        = string
  default     = ""
}

variable "vnet_resource_group" {
  type = string
}

variable "public_network_access" {
  type    = bool
  default = false
}

variable "testzone" {
  type    = bool
  default = false
}

variable "environment" {
  type = string
}

variable "appconfig_sku" {
  type    = string
  default = "developer"
}
