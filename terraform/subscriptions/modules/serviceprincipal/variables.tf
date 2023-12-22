variable "client_id" {
  description = "The client ID of the application for which to create a service principal."
  type        = string
}
variable "app_role_assignment_required" {
  description = "Whether this service principal requires an app role assignment to a user or group before Azure AD will issue a user or access token to the application."
  type        = string
}

variable "owners" {
  description = "A set of object IDs of principals that will be granted ownership of the service principal."
  type        = set(string)
}
