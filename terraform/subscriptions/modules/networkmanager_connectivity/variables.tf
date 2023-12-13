variable "enviroment" {
  description = "Enviroment (dev/playground/prod/c2)"
  type        = string
}

variable "network_manager_id" {
  description = "Specifies the ID of the Network Manager"
  type        = string
}


variable "network_group_id" {
  description = "Specifies the resource ID used as in Network group"
  type        = string
}
variable "vnethub_id" {
  description = "Specifies the resource ID used as hub in Hub And Spoke"
  type        = string
}