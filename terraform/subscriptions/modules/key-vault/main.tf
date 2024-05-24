resource "azurerm_key_vault" "this" {
  name                = var.vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  # enabled_for_disk_encryption = true
  tenant_id                  = var.tenant_id
  soft_delete_retention_days = 90
  purge_protection_enabled   = var.purge_protection_enabled
  enable_rbac_authorization  = var.enable_rbac_authorization
  tags = {
    IaC = "terraform"
  }
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = [var.ip_rule]
  }

  sku_name = "standard"
}


data "azurerm_subnet" "subnet" {
  name                 = "private-links"
  virtual_network_name = var.virtual_network
  resource_group_name  = var.vnet_resource_group
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

