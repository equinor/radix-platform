data "azurerm_client_config" "current" {}

data "azuread_group" "this" {
  display_name     = "Radix Platform Operators"
  security_enabled = true
}

data "azurerm_role_definition" "this" {
  name = "Key Vault Secrets User"
}

data "external" "keyvault_secret" {
  program = ["python3", "${path.module}/get_secret.py"]
  query = {
    vault           = "${var.vault_name}"
    name            = "kubernetes-api-auth-ip-range"
    subscription_id = data.azurerm_client_config.current.subscription_id
  }
}

resource "azurerm_key_vault" "this" {
  name                          = var.vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = var.testzone ? 7 : 90
  purge_protection_enabled      = var.testzone ? false : true
  enable_rbac_authorization     = var.enable_rbac_authorization
  public_network_access_enabled = true
  tags = {
    IaC = "terraform"
  }
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = jsondecode(data.external.keyvault_secret.result.value)
  }


  sku_name = "standard"
}

resource "azurerm_role_assignment" "this" {
  scope              = azurerm_key_vault.this.id
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}${data.azurerm_role_definition.this.role_definition_id}"
  principal_id       = var.kv_secrets_user_id
}

data "azurerm_subnet" "subnet" {
  name                 = "private-links"
  virtual_network_name = "vnet-hub"
  resource_group_name  = var.vnet_resource_group
}

resource "azurerm_key_vault_access_policy" "this" {
  for_each     = var.enable_rbac_authorization == false ? { "${var.vault_name}" : true } : {}
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_group.this.object_id
  certificate_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "ManageContacts", "ManageIssuers", "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers"
  ]
  key_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore"
  ]
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
  ]
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.vault_name}"
  location            = var.location
  resource_group_name = var.vnet_resource_group
  subnet_id           = data.azurerm_subnet.subnet.id
  depends_on          = [azurerm_key_vault.this]

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
  tags = {
    IaC = "terraform"
  }
}
resource "azurerm_private_dns_a_record" "this" {
  name                = azurerm_key_vault.this.name
  zone_name           = "privatelink.vaultcore.azure.net"
  resource_group_name = var.vnet_resource_group
  ttl                 = 60
  records             = [azurerm_private_endpoint.this.private_service_connection.0.private_ip_address]
}

output "azurerm_key_vault_id" {
  value = azurerm_key_vault.this.id
}

##  Azure App Configuration

resource "azurerm_user_assigned_identity" "app_config" {
  name                = "radix-id-appconfig-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_app_configuration" "this" {
  name                                 = "radix-appconfig-${var.environment}"
  resource_group_name                  = var.resource_group_name
  location                             = var.location
  sku                                  = var.appconfig_sku
  local_auth_enabled                   = true
  public_network_access                = "Enabled"
  purge_protection_enabled             = var.appconfig_sku == "developer" ? false : true # This field only works for standard sku
  data_plane_proxy_authentication_mode = "Pass-through"
  # soft_delete_retention_days  = var.appconfig_sku == "developer" ? null : 7

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.app_config.id,
    ]
  }
}

output "azurerm_app_configuration_id" {
  value = azurerm_app_configuration.this.id
}
