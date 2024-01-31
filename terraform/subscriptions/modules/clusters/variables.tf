
variable "subscription" {
  description = "The ID of the Subscription where this Policy Assignment should be created"
  type        = string
}

variable "resource_groups" {
  description = "The list of resource groups to find clusters"
  type = list(string)
}
