variable "displayname" {
  type = string
}

variable "service_management_reference" {
  type = string
}

variable "internal_notes" {
  type    = string
  default = ""
}

variable "radixowners" {
  type = list(string)
}

variable "permissions" {
  type = map(object({
    id        = string
    scope_ids = list(string)
  }))
  default = {}
}

variable "implicit_id_token_issuance_enabled" {
  type    = bool
  default = false
}

variable "app_role_assignment_required" {
  type    = bool
  default = false
}

variable "audience" {
  type    = string
  default = "AzureADMyOrg"
}

variable "token_version" {
  type    = number
  default = 1
}

variable "app_roles" {
  type = map(object({
    Displayname = string
    Membertype  = string
    Value       = string
    Description = string
  }))
  default = {}
}

variable "role_assignments" {
  type = map(object({
    principal_object_id = string
    role_key            = string
  }))
  default = {}
}
