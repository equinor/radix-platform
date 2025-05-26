variable "sqlserver-developer-group" {
  type = map(string)
  default = {
    dev        = "Radix SQL server admin - dev",
    playground = "Radix SQL server admin - playground",
    ext-mon    = "Radix SQL server admin - extmon",

  }
}
variable "sqlserver-operators-group" {
  type = map(string)
  default = {
    platform = "Radix SQL server admin - platform",
    c2       = "Radix SQL server admin - c2",

  }
}

variable "subscriptions" {
  type = map(string)
  default = {
    s612 = "939950ec-da7e-4349-8b8d-77d9c278af04"
    s940 = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    s941 = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  }
}

variable "all_subscriptions" {
  type    = list(string)
  default = ["/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a", "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b", "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04"]
}


variable "operator-roles" {
  type = map(object({
    role         = string
    subscription = string
  }))
  default = {
    s940 = { role = "Key Vault Secrets Officer", subscription : "s940" }
  }
}
variable "developer-roles" {
  type = map(object({
    role         = string
    subscription = string
  }))
  default = {
    s941 = { role = "Key Vault Secrets Officer", subscription : "s941" }
  }
}

variable "service-manager-ref" {
  type        = string
  default     = "110327"
  description = "Service Manager Reference, required on all App Registrations"
}

variable "appregistrations" {
  description = "App registrations"
  type = map(object({
    display_name                       = string
    service_management_reference       = string
    notes                              = optional(string)
    implicit_id_token_issuance_enabled = optional(bool, false)
    app_role_assignment_required       = optional(bool, false)
    sign_in_audience                   = optional(string)
    token_version                      = optional(number)
    permissions = optional(map(object({
      id        = string
      scope_ids = list(string)
    })))
  }))
  default = {
    servicenow_proxy_client = {
      display_name                 = "ar-radix-servicenow-proxy-client"
      service_management_reference = "110327"
      token_version                = 2
      permissions = {
        msgraph = {
          id = "00000003-0000-0000-c000-000000000000" # msgraph
          scope_ids = [
            "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
          ]
        }
      }
    }
  }
}

