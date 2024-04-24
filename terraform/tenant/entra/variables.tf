variable "sqlserver-developer-group" {
  type = map(string)
  default = {
    dev        = "Radix SQL server admin - dev",
    playground = "Radix SQL server admin - playground",
    ext-mon    = "Radix SQL server admin - ext-mon",
  }
}
variable "sqlserver-operators-group" {
  type = map(string)
  default = {
    platform = "Radix SQL server admin - platform",
    c2       = "Radix SQL server admin - c2",
  }
}

variable "subscriptions" {
  type = map(string)
  default = {
    s940 = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    s941 = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  }
}

variable "operator-roles" {
  type = map(object({
    role         = string
    subscription = string
  }))
  default = {
    s940 = { role = "Key Vault Secrets Officer", subscription : "s940" }
  }
}
variable "developer-roles" {
  type = map(object({
    role         = string
    subscription = string
  }))
  default = {
    s941 = { role = "Key Vault Secrets Officer", subscription : "s941" }
  }
}

variable "service-manager-ref" {
  type        = string
  default     = "110327"
  description = "Service Manager Reference, required on all App Registrations"
}
