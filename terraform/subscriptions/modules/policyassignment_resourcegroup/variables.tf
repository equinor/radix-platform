variable "policy_name" {
  description = "The Name which should be used for this Resource Group."
  type        = string
}

variable "location" {
  description = "The Name which should be used for this Resource Group."
  type        = string
}


variable "resource_group_id" {
  description = "The Azure Region where the Resource Group should exist."
  type        = string
}

variable "policy_definition_id" {
  description = "The ID of the Policy Definition or Policy Definition Set."
  type        = string

}

variable "identity_ids" {
  description = "A list of User Managed Identity IDs which should be assigned to the Policy Definition"
  type        = string

}

variable "workspaceId" {
  description = "The Workspace(Log Analytics) ID where the Logs are going to be sent to"
  type        = string

}

