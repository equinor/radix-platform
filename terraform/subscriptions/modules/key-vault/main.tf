data "azuread_group" "this" {
  display_name     = "Radix Platform Operators"
  security_enabled = true
}

data "azurerm_role_definition" "this" {
  name = "Key Vault Secrets User"
}

resource "azurerm_key_vault" "this" {
  name                          = var.vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  soft_delete_retention_days    = 90
  purge_protection_enabled      = var.purge_protection_enabled
  enable_rbac_authorization     = var.enable_rbac_authorization
  public_network_access_enabled = true
  tags = {
    IaC = "terraform"
  }
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = var.ip_rule
  }

  sku_name = "standard"
}

resource "azurerm_role_assignment" "this" {
  for_each           = var.enable_rbac_authorization && length(var.kv_secrets_user_id) > 0 ? { "${var.vault_name}" : true } : {}
  scope              = azurerm_key_vault.this.id
  role_definition_id = data.azurerm_role_definition.this.role_definition_id
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
  tenant_id    = var.tenant_id
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

