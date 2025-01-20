data "azuread_application_published_app_ids" "well_known" {}
data "azuread_service_principal" "servicenow" {
  display_name = "ar-radix-servicenow-proxy-server"
}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}
data "azuread_service_principal" "kubernetes" {
  client_id = data.azuread_application_published_app_ids.well_known.result["AzureKubernetesServiceAadServer"]
}

module "webconsole" {
  source              = "../../../modules/app_registration"
  display_name        = "Omnia Radix Web Console - Development"
  notes               = "Omnia Radix Web Console - Development"
  service_id          = "110327"
  owners              = keys(jsondecode(data.azurerm_key_vault_secret.radixowners.value))
  assignment_required = true
  resource_access = {
    servicenow = {
      app_id = data.azuread_service_principal.servicenow.client_id
      scope_ids = [
        data.azuread_service_principal.servicenow.oauth2_permission_scope_ids["Application.Read"]
      ]
    }
    kubernetes = {
      app_id = data.azuread_application_published_app_ids.well_known.result["AzureKubernetesServiceAadServer"]
      scope_ids = [
        data.azuread_service_principal.kubernetes.oauth2_permission_scope_ids["user.read"],
      ]
    }
    msgraph = {
      app_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
      scope_ids = [
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["Application.Read.All"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["GroupMember.Read.All"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["offline_access"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["profile"],
      ]
    }
  }
}