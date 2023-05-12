variable "K8S_ENVIROMENTS" {
  description = "A list of cluster enviroments"
  type        = list(string)
}

variable "AZ_SUBSCRIPTION_SHORTNAME" {
  description = "Subscription shortname"
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}