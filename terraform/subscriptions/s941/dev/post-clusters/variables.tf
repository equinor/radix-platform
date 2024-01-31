variable "resource_groups" {
  type    = list(string)
  default = ["clusters-dev"]
}

variable "subscription" {
  description = "The ID of the Subscription where this Policy Assignment should be created"
  type        = string
  default =
}
