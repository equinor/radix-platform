resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group
  security_rule {

    access                                     = "Allow"
    destination_address_prefixes               = var.ingressIP
    destination_application_security_group_ids = []
    destination_port_ranges                    = ["80", "443"]
    direction                                  = "Inbound"
    name                                       = "nsg-${var.cluster_name}-rule"
    priority                                   = 100
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    # source_address_prefixes                    = []
    source_application_security_group_ids = []
    source_port_range                     = "*"
    source_port_ranges                    = []

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

  subnet {
    name                            = "subnet-${var.cluster_name}"
    address_prefixes                = ["${var.address_space}/18"]
    security_group                  = azurerm_network_security_group.this.id
    default_outbound_access_enabled = false
    service_endpoints               = var.service_endpoints
  }
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
