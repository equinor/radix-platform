variable "network_security_perimeter_name" {
  description = "Name the network security perimeter."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the network security perimeter."
  type        = string
}

variable "location" {
  description = "Azure region for the network security perimeter."
  type        = string
}

variable "profile_name" {
  description = "Name of the network security perimeter profile."
  type        = string
  default     = "defaultProfile"
}

variable "associations" {
  description = "Named resource associations for the network security perimeter profile. All associations are Enforced."
  type = map(object({
    name        = string
    resource_id = string
  }))
  default = {}
}
