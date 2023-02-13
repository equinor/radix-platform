variable "AZ_TENANT_ID" {
  description = "Tenant ID"
  type        = string
}

variable "AZ_RESOURCE_GROUP_COMMON" {
  description = "Resource group name for common"
  type        = string
}

variable "SP_GITHUB_DEV_CLUSTER_CLIENT_ID" {
  description = "Service principal"
  type        = string
}

variable "KV_RADIX_VAULT_DEV" {
  description = "Radix development keyvault"
  type        = string
}
