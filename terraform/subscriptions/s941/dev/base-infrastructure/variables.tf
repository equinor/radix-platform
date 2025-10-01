
variable "storageaccounts" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    name                     = string
    account_tier             = optional(string, "Standard")
    account_replication_type = optional(string, "LRS")
    kind                     = optional(string, "StorageV2")
    change_feed_enabled      = optional(bool, false)
    versioning_enabled       = optional(bool, false)
    backup                   = optional(bool, false)
    principal_id             = optional(string)
    private_endpoint         = optional(bool, false)
    lifecyclepolicy          = optional(bool, false)
  }))
  default = {
    log = {
      name = "log"
    },
    velero = {
      name            = "velero"
      lifecyclepolicy = true
    }
  }
}

variable "appregistrations" {
  description = "App registrations"
  type = map(object({
    display_name                       = string
    service_management_reference       = string
    notes                              = string
    implicit_id_token_issuance_enabled = optional(bool, false)
    app_role_assignment_required       = optional(bool, false)
    permissions = optional(map(object({
      id        = string
      scope_ids = list(string)
    })))
    app_roles = map(object({
      Displayname = string
      Membertype  = string
      Value       = string
      Description = string
    }))
    role_assignments = map(object({
      principal_object_id = string
      role_key            = string
    }))
    optional_id_token_claims = list(string)
  }))
  default = {
    webconsole = {
      display_name                 = "Omnia Radix Web Console - Development"
      service_management_reference = "110327"
      notes                        = "Omnia Radix Web Console - Development"
      app_role_assignment_required = true
      permissions = {
        msgraph = {
          id = "00000003-0000-0000-c000-000000000000" # msgraph
          scope_ids = [
            "c79f8feb-a9db-4090-85f9-90d820caa0eb", # Application.Read.All
            "bc024368-1153-4739-b217-4326f2e966d0", # GroupMember.Read.All
            "e1fe6dd8-ba31-4d61-89e7-88639da4683d", # User.Read
            "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", # offline_access
            "37f7f235-527c-4136-accd-4a02d197296e", # openid
            "14dad69e-099b-42c9-810b-d002981feec1"  # profile
          ]
        }
        servicenow_proxy_server = {
          id = "1b4a22f1-d4a1-4b6a-81b2-fd936daf1786" # ar-radix-servicenow-proxy-server
          scope_ids = [
            "4781537a-ed53-49fd-876b-32c274831456" # Application.Read
          ]
        }
        kubernetes_aad_server = {
          id = "6dae42f8-4368-4678-94ff-3960e28e3630" # Azure Kubernetes Service AAD Server
          scope_ids = [
            "34a47c2f-cd0d-47b4-a93c-2c41130c671c" # user.read
          ]
        }
      }
      app_roles        = {}
      role_assignments = {}
      optional_id_token_claims = [ "login_hint" ]
    }
    grafana = {
      display_name                 = "radix-ar-grafana-dev"
      service_management_reference = "110327"
      notes                        = "Grafana Oauth, main app for user authentication to Grafana"
      permissions = {
        msgraph = {
          id = "00000003-0000-0000-c000-000000000000" # msgraph
          scope_ids = [
            "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
          ]
        }
      }
      app_roles = {
        admins = {
          Displayname = "Radix Grafana Admins"
          Membertype  = "User"
          Value       = "Admin"
          Description = "Grafana App Admins"
        }
        editors = {
          Displayname = "Radix Grafana Editors"
          Membertype  = "User"
          Value       = "Editor"
          Description = "Grafana App Editors"
        }
      }
      role_assignments = {
        radix_platform_operators = {
          principal_object_id = "be5526de-1b7d-4389-b1ab-a36a99ef5cc5"
          role_key            = "admins"
        }
        radix = {
          principal_object_id = "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d"
          role_key            = "editors"
        }
      }
      optional_id_token_claims = []
    }
    cr_cicd = {
      display_name                       = "radix-cr-cicd-dev"
      service_management_reference       = "110327"
      notes                              = "Used by radix-image-builder"
      implicit_id_token_issuance_enabled = true
      permissions                        = {}
      app_roles                          = {}
      role_assignments                   = {}
      optional_id_token_claims           = []
    }
  }
}

variable "resource_groups_common_legacy" {
  type    = string
  default = "common"
}

variable "enviroment_temporary" {
  type    = string
  default = "development"
}