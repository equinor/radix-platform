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

variable "local_authentication_disabled" {
  description = "Specifies if the Log Analytics Workspace should enforce authentication using Azure AD."
  type        = bool
  default     = true
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
