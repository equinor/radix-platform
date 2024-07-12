variable "display_name" {
  type = string
}

variable "notes" {
  type    = string
  default = ""
}

variable "service_id" {
  type = string
}


variable "web_uris" {
  type    = list(string)
  default = []
}

variable "singlepage_uris" {
  type    = list(string)
  default = []
}

variable "owners" {
  type    = list(string)
  default = []
}

variable "implicit_grant" {
  type    = bool
  default = false
}

variable "required_resource_access" {
  type = map(object({
    resource_app_id = string
    resource_access = map(object({
      id   = string
      type = string
    }))
  }))

  default = {}
}


variable "resource_access" {
  type = map(object({
    app_id    = string
    scope_ids = list(string)
  }))

  default = {}
}

variable "assignment_required" {
  type    = bool
  default = false
}