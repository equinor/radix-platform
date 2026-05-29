variable "dnszone" {
  type    = string
}

variable "create_caa_records" {
  type = bool
  default = false
}

variable "resourcegroup_common" {
  type = string
}
