variable "gitrunner_federated_credential_name" {
  description = "Name of the GitHub federated credential."
  type        = string
}

variable "gitrunner_locker_name" {
  description = "Name of the GitHub runner locker identity."
  type        = string
}

variable "gitrunner_locker_resource_group_name" {
  description = "Resource group containing the GitHub runner locker identity."
  type        = string
}

variable "keyvault_lock_creator_role_name" {
  description = "Name of the Key Vault lock creator role."
  type        = string
}

variable "location" {
  description = "Azure location for the managed identity."
  type        = string
}

variable "managed_resource_group_names" {
  description = "Additional resource groups managed by this module."
  type        = list(string)
  default     = []
}

variable "keyvault_config_name" {
  description = "Name of the config Key Vault."
  type        = string
}

variable "keyvault_config_resource_group_name" {
  description = "Resource group containing the config Key Vault."
  type        = string
}

variable "keyvault_name" {
  description = "Name of the main Key Vault."
  type        = string
}

variable "keyvault_resource_group_name" {
  description = "Resource group containing the main Key Vault."
  type        = string
}

variable "subscription_id" {
  description = "Full Azure subscription resource ID for the custom role."
  type        = string
}

variable "terraform_state_storage_account_id" {
  description = "Storage account where the locker can read Terraform state."
  type        = string
}

variable "enable_resource_locks" {
  description = "Grant Key Vault lock creation and cluster resource group lock management."
  type        = bool
  default     = false
}

variable "keyvault_vnet_resource_group" {
  description = "Virtual network resource group for the Key Vault private endpoint."
  type        = string
}

variable "keyvault_subscription_contributor" {
  description = "Contributor group name for Key Vault access."
  type        = string
}

variable "keyvault_secrets_user_id" {
  description = "Principal ID granted Key Vault Secrets User access."
  type        = string
  default     = ""
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