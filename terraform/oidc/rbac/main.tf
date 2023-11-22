terraform {}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}

provider "azuread" {}

data "azurerm_client_config" "CLIENT_CONFIG" {}

data "azurerm_subscription" "AZ_SUBSCRIPTION" {
  subscription_id = var.AZ_SUBSCRIPTION_ID
}

data "azuread_group" "radix_group" {
  display_name = var.AAD_RADIX_GROUP
}

resource "azuread_application" "APP_GITHUB_ACTION_CLUSTER" {
  display_name     = var.APP_GITHUB_ACTION_CLUSTER_NAME
  owners           = data.azuread_group.radix_group.members
  sign_in_audience = "AzureADandPersonalMicrosoftAccount"

  api {
    known_client_applications      = []
    mapped_claims_enabled          = false
    requested_access_token_version = 2
  }
}

resource "azuread_service_principal" "SP_GITHUB_ACTION_CLUSTER" {
  application_id               = azuread_application.APP_GITHUB_ACTION_CLUSTER.application_id
  app_role_assignment_required = false
  owners                       = azuread_application.APP_GITHUB_ACTION_CLUSTER.owners
}

resource "azurerm_role_assignment" "RA_CONTRIBUTOR_ROLE" {
  scope                = data.azurerm_subscription.AZ_SUBSCRIPTION.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.SP_GITHUB_ACTION_CLUSTER.object_id
}

resource "azurerm_role_assignment" "RA_STORAGE_BLOB_DATA_OWNER" {
  for_each             = { for key, value in var.storage_accounts : key => var.storage_accounts[key] if value["create_with_rbac"] }
  scope                = azurerm_storage_account.SA_INFRASTRUCTURE[each.key].id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azuread_service_principal.SP_GITHUB_ACTION_CLUSTER.object_id
}

resource "azurerm_role_assignment" "RA_USER_ACCESS_ADMINISTRATOR" {
  for_each             = { for key, value in var.storage_accounts : key => var.storage_accounts[key] if value["create_with_rbac"] }
  scope                = azurerm_storage_account.SA_INFRASTRUCTURE[each.key].id
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.SP_GITHUB_ACTION_CLUSTER.object_id
}

resource "azuread_application_federated_identity_credential" "APP_GITHUB_DEV_CLUSTER_FED" {
  application_object_id = azuread_application.APP_GITHUB_ACTION_CLUSTER.object_id
  display_name          = "${var.GH_REPOSITORY}-${var.GH_ENVIRONMENT}"
  description           = "Allow Github to authenticate"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${var.GH_ORGANIZATION}/${var.GH_REPOSITORY}:environment:${var.GH_ENVIRONMENT}"

  timeouts {}
}

resource "azurerm_storage_account" "SA_INFRASTRUCTURE" {
  for_each                         = { for key, value in var.storage_accounts : key => var.storage_accounts[key] if value["create_with_rbac"] }
  name                             = each.value["name"]
  resource_group_name              = each.value["rg_name"]
  location                         = each.value["location"]
  account_kind                     = each.value["kind"]
  account_replication_type         = each.value["repl"]
  account_tier                     = each.value["tier"]
  allow_nested_items_to_be_public  = each.value["allow_nested_items_to_be_public"]
  cross_tenant_replication_enabled = each.value["cross_tenant_replication_enabled"]
  shared_access_key_enabled        = each.value["shared_access_key_enabled"]
  tags                             = each.value["tags"]

  dynamic "blob_properties" {
    for_each = each.value["kind"] == "BlobStorage" || each.value["kind"] == "Storage" ? [1] : [0]

    content {
      change_feed_enabled           = each.value["change_feed_enabled"]
      versioning_enabled            = each.value["versioning_enabled"]
      change_feed_retention_in_days = each.value["change_feed_days"]

      dynamic "container_delete_retention_policy" {
        for_each = each.value["container_delete_retention_policy"] == true ? [30] : []

        content {
          days = container_delete_retention_policy.value
        }
      }

      dynamic "delete_retention_policy" {
        for_each = each.value["delete_retention_policy"] == true ? [35] : []

        content {
          days = delete_retention_policy.value
        }
      }

      dynamic "restore_policy" {
        for_each = each.value["backup_center"] == true ? [30] : []

        content {
          days = restore_policy.value
        }
      }
    }
  }
}

resource "azurerm_storage_container" "SA_INFRASTRUCTURE_CONTAINER_CLUSTERS" {
  for_each             = { for key, value in var.storage_accounts : key => var.storage_accounts[key] if value["create_with_rbac"] }
  storage_account_name = each.value["name"]
  name                 = "clusters"
}

resource "azurerm_storage_container" "SA_INFRASTRUCTURE_CONTAINER_INFRASTRUCTURE" {
  for_each             = { for key, value in var.storage_accounts : key => var.storage_accounts[key] if value["create_with_rbac"] }
  storage_account_name = each.value["name"]
  name                 = "infrastructure"
}
