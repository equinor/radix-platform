variable "resource_groups" {
  type    = list(string)
  default = ["clusters-playground"]
}

variable "clusters" {
  type = map(object({
    resource_group_name        = optional(string, "clusters")
    location                   = optional(string, "northeurope")
    destination_address_prefix = string
  }))
  default = {

  }
}