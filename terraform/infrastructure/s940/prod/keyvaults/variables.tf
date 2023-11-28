variable "AZ_TENANT_ID" {
  description = "Tenant ID"
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "AZ_RESOURCE_GROUP_COMMON" {
  description = "Resource group name for common"
  type        = string
}

variable "SP_GITHUB_ACTION_CLUSTER_CLIENT_ID" {
  description = "Service principal"
  type        = string
}

variable "KV_RADIX_VAULT" {
  description = "Radix keyvault"
  type        = string
}
