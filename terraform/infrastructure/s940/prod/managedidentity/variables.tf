variable "managed_identity" {
  type = map(object({
    name     = string
    location = optional(string, "northeurope")
    rg_name  = string
  }))
  default = {}
}

variable "storage_accounts" {
  type = map(object({
    name             = string
    rg_name          = string
    managed_identity = optional(bool, false)
  }))
  default = {}
}

variable "loganalytics" {
  type = map(object({
    name             = string
    rg_name          = string
    managed_identity = optional(bool, false)
  }))
  default = {}
}
