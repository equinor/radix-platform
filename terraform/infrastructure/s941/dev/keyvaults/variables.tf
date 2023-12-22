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

variable "APP_GITHUB_ACTION_CLUSTER_NAME" {
  description = "App registration name"
  type        = string
}

variable "KV_RADIX_VAULT" {
  description = "Radix keyvault"
  type        = string
}
