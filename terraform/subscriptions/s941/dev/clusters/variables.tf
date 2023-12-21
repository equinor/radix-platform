variable "clusters" {
  type = map(object({
    resource_group_name = optional(string, "clusters")
    #destination_address_prefix = string
  }))
  default = {
    weekly-50 = {
      destination_address_prefix = "20.223.40.151"
    }
    # ,
    # weekly-51 = {}
  }
}
