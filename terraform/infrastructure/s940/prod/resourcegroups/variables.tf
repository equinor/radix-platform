variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "resource_groups" {
  type = map(object({
    name     = string                          # Mandatory
    location = optional(string, "northeurope") # Optional
  }))
  default = {}
}
