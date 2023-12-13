variable "enviroment" {
  description = "Enviroment (dev/playground/prod/c2)"
  type        = string
}

variable "location" {
  description = "Specifies the Azure Region where the Network Managers should exist. Changing this forces a new resource to be created."
  type        = string
}

variable "policy_id" {
  description = "The ID of the Policy Definition or Policy Definition Set."
  type        = string
}

variable "subscription" {
  description = "The ID of the Subscription where this Policy Assignment should be created"
  type        = string
}