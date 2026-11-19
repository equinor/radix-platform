variable "workspace_name" {
  description = "The name of this Log Analytics workspace."
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

variable "retention_in_days" {
  description = "The number of days that logs should be retained."
  type        = number
  default     = 90
}

variable "diagnostic_setting_enabled_log_categories" {
  description = "A list of log categories to be enabled for this diagnostic setting."
  type        = list(string)
  default     = ["Audit"]
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}

variable "sku" {
  type    = string
  default = "PerGB2018"
}

variable "acr_reservation" {
  type    = number
  default = null
}

variable "ampls_enabled" {
  description = "Associate this workspace with AMPLS. The private endpoint is managed separately, once per VNet."
  type        = bool
  default     = false
}

variable "ampls_scope_name" {
  description = "The name of the Azure Monitor Private Link Scope."
  type        = string
  default     = null

  validation {
    condition     = !var.ampls_enabled || try(trimspace(var.ampls_scope_name) != "", false)
    error_message = "ampls_scope_name must be provided when ampls_enabled is true."
  }
}

variable "ampls_resource_group" {
  description = "Resource group containing the AMPLS instance."
  type        = string
  default     = null

  validation {
    condition     = !var.ampls_enabled || try(trimspace(var.ampls_resource_group) != "", false)
    error_message = "ampls_resource_group must be provided when ampls_enabled is true."
  }
}
