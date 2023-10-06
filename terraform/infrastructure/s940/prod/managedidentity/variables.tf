variable "managed_identity" {
  type = map(object({
    name     = string
    location = optional(string, "northeurope")
    rg_name  = optional(string, "Logs")
  }))
  default = {}
}

variable "storage_accounts" {
  type = map(object({
    name                              = string                          # Mandatory
    rg_name                           = string                          # Mandatory
    managed_identity                  = optional(bool, false)
  }))
  default = {}
}

variable "loganalytics" {
  type = map(object({
    name                              = string                          # Mandatory
    rg_name                           = string                          # Mandatory
    managed_identity                  = optional(bool, false)
  }))
  default = {}
}