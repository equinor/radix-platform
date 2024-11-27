resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group
  security_rule {

    access                     = "Allow"
    destination_address_prefix = var.ingressIP
    destination_port_ranges    = ["80", "443"]
    direction                  = "Inbound"
    name                       = "nsg-${var.cluster_name}-rule"
    priority                   = 100
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"

  }

  tags = {
    IaC = "terraform"
  }
}

data "azurerm_network_watcher" "this" {
  name                = "NetworkWatcher_${var.location}"
  resource_group_name = "NetworkWatcherRG"
}


resource "azurerm_network_watcher_flow_log" "this" {
  network_watcher_name = data.azurerm_network_watcher.this.name
  resource_group_name  = data.azurerm_network_watcher.this.resource_group_name
  name                 = "nsg-${var.cluster_name}-flow-log"

  network_security_group_id = azurerm_network_security_group.this.id
  storage_account_id        = var.storageaccount_id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 90
  }
  tags = {
    IaC = "terraform"
  }
  depends_on = [azurerm_network_security_group.this]
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = ["${var.address_space}/16"]

  dynamic "ddos_protection_plan" {
    for_each = var.enviroment == "platform" || var.enviroment == "c2" ? [1] : []
    content {
      enable = true
      id     = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/rg-protection-we/providers/Microsoft.Network/ddosProtectionPlans/ddos-protection"
    }

  }

  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_subnet" "this" {
  name                            = "subnet-${var.cluster_name}"
  resource_group_name             = var.resource_group
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["${var.address_space}/18"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
  depends_on                = [azurerm_virtual_network.this]
}


resource "azurerm_management_lock" "network" {
  for_each   = var.enviroment == "platform" || var.enviroment == "c2" ? { "${azurerm_virtual_network.this.name}" : true } : {}
  name       = "${azurerm_virtual_network.this.name}-CanNotDelete-Lock"
  scope      = azurerm_virtual_network.this.id
  lock_level = "CanNotDelete"
  notes      = "IaC : Terraform"
}

output "vnet" {
  value = azurerm_virtual_network.this
}

output "subnet" {
  value = azurerm_subnet.this
}