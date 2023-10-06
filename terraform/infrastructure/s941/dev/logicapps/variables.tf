variable "AZ_LOCATION" {
  description = "The location to create the resources in."
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "logic_app_workflow" {
  description = "Logic App Workflows"
  type = map(object({
    name                  = string
    location              = optional(string, "northeurope")
    rg_name               = optional(string, "Logs-Dev")
    managed_identity_name = string
    loganalytics          = string
    storageaccount        = string
    folder                = string
  }))
  default = {}
}

variable "managed_identity" {
  description = "Managed Identity"
  type = map(object({
    name    = string
    rg_name = optional(string, "Logs-Dev")

  }))
  default = {}
}
