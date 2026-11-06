variable "environment" {
  description = "Zone environment used for the GitHub federated credential."
  type        = string
}

variable "locker_environment" {
  description = "Override for existing locker identity and custom role names. Defaults to environment."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure location for the managed identity."
  type        = string
}

variable "subscription_id" {
  description = "Full Azure subscription resource ID for the custom role."
  type        = string
}

variable "common_resource_group_name" {
  description = "Resource group containing the locker identity."
  type        = string
}

variable "terraform_state_storage_account_id" {
  description = "Storage account where the locker can read Terraform state."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault where the locker can update configuration."
  type        = string
}

variable "enable_resource_locks" {
  description = "Grant Key Vault lock creation and cluster resource group lock management."
  type        = bool
  default     = false
}

variable "clusters_resource_group_id" {
  description = "Cluster resource group to lock. Required when resource locks are enabled."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_resource_locks || var.clusters_resource_group_id != null
    error_message = "clusters_resource_group_id must be provided when enable_resource_locks is true."
  }
}