variable "resource_groups" {
  type = map(object({
    name     = string                          # Mandatory
    location = optional(string, "northeurope") # Optional
  }))
  default = {}
}
