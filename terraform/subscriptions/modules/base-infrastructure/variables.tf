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

variable "common_resource_group" {
  description = "Common resource group name for shared resources."
  type        = string
}

variable "vnet_resource_group" {
  description = "Resource group containing the virtual network."
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

variable "ampls_name" {
  description = "Name of the AMPLS instance."
  type        = string
  default     = ""

  validation {
    condition     = !var.ampls_enabled || try(trimspace(var.ampls_name) != "", false)
    error_message = "ampls_name must be provided when ampls_enabled is true."
  }
}

variable "ampls_enabled" {
  description = "Flag to enable or disable AMPLS."
  type        = bool
  default     = false
}

variable "ampls_private_endpoint_name" {
  description = "Name of the AMPLS private endpoint."
  type        = string
  default     = null

  validation {
    condition     = !var.ampls_enabled || try(trimspace(var.ampls_private_endpoint_name) != "", false)
    error_message = "ampls_private_endpoint_name must be provided when AMPLS is enabled."
  }
}

variable "virtual_network_private_dns_zone" {
  description = "Private DNS zones available to the AMPLS private endpoint."
  type        = map(any)
  default     = {}
}

variable "virtual_network_subnet_id" {
  description = "Subnet ID for the AMPLS private endpoint."
  type        = string
  default     = null

  validation {
    condition     = !var.ampls_enabled || try(trimspace(var.virtual_network_subnet_id) != "", false)
    error_message = "virtual_network_subnet_id must be provided when AMPLS is enabled."
  }
}

variable "vnet_resource_group" {
  description = "Resource group containing the virtual network."
  type        = string
  default     = null

  validation {
    condition     = !var.ampls_enabled || try(trimspace(var.vnet_resource_group) != "", false)
    error_message = "vnet_resource_group must be provided when ampls_enabled is true."
  }
}
variable "easyauth" {
  description = "Radix EasyAuth settings. EasyAuth (app registration, Dex managed identity and Postgres server) is created only when set."
  type = object({
    app_display_name          = string
    allowed_group_names       = list(string)
    dex_mi_name               = string
    app_owners                = list(string)
    postgres_server_name      = string
    postgres_admin_group_name = string
    postgres_sku_name         = optional(string, "B_Standard_B1ms")
    postgres_version          = optional(string, "17")
    postgres_storage_mb       = optional(number, 32768)
  })
  default = null

  validation {
    condition     = var.easyauth == null || length(try(var.easyauth.allowed_group_names, [])) > 0
    error_message = "easyauth.allowed_group_names must contain at least one group."
  }
}
