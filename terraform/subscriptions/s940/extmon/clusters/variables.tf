variable "resource_groups" {
  type    = list(string)
  default = ["clusters-extmon"]
}

variable "clusters" {
  type = map(object({
    resource_group_name        = optional(string, "clusters-extmon")
    location                   = optional(string, "northeurope")
    destination_address_prefix = string
  }))
  default = {
    # weekly-52 = {
    #   destination_address_prefix = "20.223.40.149"
    # }
    # weekly-01 = {
    #   destination_address_prefix = "20.223.40.148"
    # }
  }
}