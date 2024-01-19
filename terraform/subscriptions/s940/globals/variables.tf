variable "resource_groups" {
  description = "Shared resourcegroups across enviroments."
  type = map(object({
    location = optional(string, "northeurope")
  }))
  default = {
  }
}
