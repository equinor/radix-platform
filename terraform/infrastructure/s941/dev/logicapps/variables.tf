
variable "logic_app_workflow" {
  description = "Logic App Workflows"
  type = map(object({
    name     = string
    location = optional(string, "northeurope")
    id       = string
    rg_name  = optional(string, "Logs-Dev")
  }))
  default = {}
}
