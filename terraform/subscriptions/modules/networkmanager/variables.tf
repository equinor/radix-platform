variable "location" {
  description = "Specifies the Azure Region where the Network Managers should exist. Changing this forces a new resource to be created."
  type        = string
}

variable "subscription_shortname" {
  description = "The shortname to the subscription"
  type        = string
}

variable "resource_group" {
  description = "Specifies the name of the Resource Group where the Network Managers should exist."
  type        = string
}

variable "subscription" {
  description = "The subscription ID"
  type        = string
}

# variable "enviroment" {
#   description = "Enviroment (dev/playground/prod/c2)"
#   type        = string
# }

# variable "network_manager_id" {
#   description = "Specifies the ID of the Network Manager"
#   type        = string
# }

# variable "vnethub_id" {
#   description = "Specifies the resource ID used as hub in Hub And Spoke"
#   type        = string
# }