variable "sqlserver-developer-group" {
  type = map(string)
  default = {
    dev        = "Radix SQL server admin - dev",
    playground = "Radix SQL server admin - playground",
    ext-mon    = "Radix SQL server admin - extmon",

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
    s612 = "939950ec-da7e-4349-8b8d-77d9c278af04"
    s940 = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    s941 = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  }
}

variable "all_subscriptions" {
  type    = list(string)
  default = ["/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a", "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b", "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04"]
}

variable "service-manager-ref" {
  type        = string
  default     = "110327"
  description = "Service Manager Reference, required on all App Registrations"
}
