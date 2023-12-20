variable "resource_groups" {
  type = map(object({
    location = optional(string, "northeurope")
  }))
  default = {
    backups            = {},
    clusters           = {},
    common             = {},
    cost-allocation    = {},
    Logs-Dev           = {},
    vulnerability-scan = {}
  }
}
