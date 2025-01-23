variable "displayname" {
  type = string
}

variable "service_management_reference" {
  type = string
}

variable "internal_notes" {
  type = string
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