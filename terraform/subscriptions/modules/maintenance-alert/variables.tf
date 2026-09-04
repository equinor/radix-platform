variable "cluster_name" {
  type = string
}

variable "enabled" {
  description = "Whether to create the maintenance reminder resources for this cluster."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace used as the scope for the reminder's scheduled query rule."
  type        = string
}

variable "key_vault_name" {
  description = "Name of the config Key Vault holding the 'slack-webhook' secret."
  type        = string
}

variable "key_vault_resource_group" {
  type = string
}

variable "email_address" {
  type = string
}

variable "week_index" {
  description = "Week of the month the node OS maintenance runs on: First, Second, Third or Fourth."
  type        = string
}

variable "day_of_week" {
  description = "Day of the week the node OS maintenance runs on, e.g. Thursday."
  type        = string
}

variable "days_before" {
  description = "How many days before the scheduled maintenance the reminder should fire."
  type        = number
  default     = 7
}

variable "start_time" {
  description = "Start time of the maintenance window, matching the aks module's maintenance_window_node_os.start_time."
  type        = string
  default     = "00:00"
}

variable "utc_offset" {
  description = "UTC offset of the maintenance window, matching the aks module's maintenance_window_node_os.utc_offset."
  type        = string
  default     = "+01:00"
}

variable "duration_hours" {
  description = "Duration of the maintenance window in hours, matching the aks module's maintenance_window_node_os.duration."
  type        = number
  default     = 6
}
