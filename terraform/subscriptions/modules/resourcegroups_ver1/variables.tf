variable "name" {
  description = "The Name which should be used for this Resource Group."
  type        = string
}

variable "location" {
  description = "The Azure Region where the Resource Group should exist."
  type        = string
}

variable "roleassignment" {
  description = "True/False if setting Roleassignment to the Resource Group."
  type        = bool

}

variable "role_definition_name" {
  description = "The name of a Role"
  type        = string

}

variable "principal_id" {
  description = "The ID of the Principal (User, Group or Service Principal) to assign the Role Definition to"
  type        = string

}
