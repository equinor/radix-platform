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
