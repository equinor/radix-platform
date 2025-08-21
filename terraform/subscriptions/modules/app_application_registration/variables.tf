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

variable "grafana_app_roles" {
  type = map(object({
    Displayname = string
    Membertype  = string
    Value       = string
    Description = string
  }))
  default = {
    admins = {
      Displayname = "Radix Grafana Admins"
      Membertype  = "User"
      Value       = "Admin"
      Description = "Grafana App Admins"
    }
    editors = {
      Displayname = "Radix Grafana Editors"
      Membertype  = "User"
      Value       = "Editor"
      Description = "Grafana App Editor"
    }
  }
}


variable "grafana_role_assignments" {
  type = map(object({
    principal_object_id = string
    role_key            = string
  }))
  default = {
    radix_platform_operators = {
      principal_object_id = "be5526de-1b7d-4389-b1ab-a36a99ef5cc5"
      role_key            = "admins"
    }
    radix = {
      principal_object_id = "ec8c30af-ffb6-4928-9c5c-4abf6ae6f82e"
      role_key            = "editors"
    }
  }
}
