variable "name" {
  description = "Specifies the name of this User Assigned Identity."
  type        = string
}

variable "resource_group_name" {
  description = "Specifies the name of the Resource Group within which this User Assigned Identity should exist."
  type        = string
}

variable "location" {
  description = "The Azure Region where the User Assigned Identity should exist."
  type        = string
}

variable "roleassignments" {
  type = map(object({
    role     = string
    scope_id = string
  }))
  default = {}
}

variable "federated_credentials" {
  type = map(object({
    name    = string
    issuer  = string
    subject = string
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
