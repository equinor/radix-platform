variable "parent_id" {
  description = "Specifies parent ID of User Assigned Identity for this Federated Identity Credential."
  type        = string
}
variable "name" {
  description = "Specifies the name of this Federated Identity Credential."
  type        = string
}
variable "audiences" {
  description = "Specifies the audience for this Federated Identity Credential."
  type        = list(string)
}
variable "issuer" {
  description = "Specifies the issuer of this Federated Identity Credential."
  type        = string
}
variable "subject" {
  description = "Specifies the subject for this Federated Identity Credential."
  type        = string
}
variable "resource_group_name" {
  description = "Specifies the name of the Resource Group within which this Federated Identity Credential should exist."
  type        = string
}