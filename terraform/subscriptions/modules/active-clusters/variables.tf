variable "resource_group_name" {
  description = "Specifies the name of the Resource Group within which this Federated Identity Credential should exist."
  type        = string
}

variable "subscription" {
  description = "The subscription ID"
  type        = string
}
