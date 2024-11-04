variable "cluster_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "autostartupschedule" {
  type    = bool
  default = false
}

variable "migrationStrategy" {
  type = string
}

variable "developers" {
  type    = list(any)
  default = ["a5dfa635-dc00-4a28-9ad9-9e7f1e56919d"]
}

variable "outbound_ip_address_ids" {
  type = list(any)
}

variable "tenant_id" {
  type    = string
  default = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
}

variable "node_os_upgrade_channel" {
  type = string
}