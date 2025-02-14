#App ACR
resource "azurerm_container_registry" "this" {
  name                          = "radix${var.acr}app"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  zone_redundancy_enabled       = false
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
  tags = {
    IaC = "terraform"
  }
  lifecycle {
    prevent_destroy = true
  }
  network_rule_set {
    default_action = "Deny"

    ip_rule = [
      {
        action   = "Allow"
        ip_range = var.ip_rule
      }
    ]
  }
  georeplications {
    location                  = var.location == "northeurope" ? "westeurope" : "northeurope"
    zone_redundancy_enabled   = false
    regional_endpoint_enabled = false
  }
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-radix-acr-app-${var.acr}"
  resource_group_name = var.vnet_resource_group
  location            = var.location
  subnet_id           = var.subnet_id
  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_container_registry.this.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_private_dns_a_record" "dns_record" {
  for_each = {
    for k, v in azurerm_private_endpoint.this.custom_dns_configs : v.fqdn => v #if length(regexall("\\.", v.fqdn)) >= 3
  }
  name                = replace(each.key, ".azurecr.io", "")
  zone_name           = "privatelink.azurecr.io"
  resource_group_name = var.vnet_resource_group
  ttl                 = 300
  records             = toset(each.value.ip_addresses)
  tags = {
    IaC = "terraform"
  }
  depends_on = [azurerm_private_endpoint.this]
}

resource "azurerm_management_lock" "this" {
  name       = "delete-lock"
  scope      = azurerm_container_registry.this.id
  lock_level = "CanNotDelete"
  notes      = "IaC : Terraform"
}

#Env ACR
resource "azurerm_container_registry" "env" {
  name     = "radix${var.acr}" == "radixc2" ? "radixc2prod" : "radix${var.acr}"
  location = var.location
  # resource_group_name           = var.acr == "c2" ? "common-westeurope" : var.resource_group_name
  # 
  resource_group_name           = var.acr == "c2" ? "common-westeurope" : var.acr == "dev" ? var.common_res_group : var.resource_group_name
  sku                           = "Premium"
  zone_redundancy_enabled       = false
  admin_enabled                 = true
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
  # retention_policy_in_days      = var.retention_policy_env
  tags = {
    IaC = "terraform"
  }
  lifecycle {
    prevent_destroy = true
  }
  network_rule_set {
    default_action = "Deny"
    ip_rule = [
      {
        action   = "Allow"
        ip_range = var.ip_rule
      },
      {
        action   = "Allow"
        ip_range = "185.55.105.28"
      }
    ]
  }
  georeplications {
    location                  = var.location == "northeurope" ? "westeurope" : "northeurope"
    zone_redundancy_enabled   = false
    regional_endpoint_enabled = true
  }
}

resource "azurerm_container_registry_task" "build_push" {
  name                  = "radix-image-builder-build-push"
  container_registry_id = azurerm_container_registry.env.id
  platform {
    os           = "Linux"
    architecture = "amd64"
  }
  agent_setting {
    cpu = 2
  }

  base_image_trigger {
    enabled                     = true
    name                        = "defaultBaseimageTriggerName"
    type                        = "Runtime"
    update_trigger_payload_type = "Default"
  }
  tags = {
    IaC = "terraform"
  }
  encoded_step {
    task_content = <<EOF
  version: v1.1.0
  stepTimeout: 3600
  steps:
    - build: >-
        --tag {{.Values.IMAGE}}
        --tag {{.Values.CLUSTERTYPE_IMAGE}}
        --tag {{.Values.CLUSTERNAME_IMAGE}}
        --file {{.Values.DOCKER_FILE_NAME}}
        .
        {{.Values.BUILD_ARGS}}
    - push:
        - {{.Values.IMAGE}}
        - {{.Values.CLUSTERTYPE_IMAGE}}
        - {{.Values.CLUSTERNAME_IMAGE}}
  EOF
  }
  identity {
    type = "SystemAssigned"
  }
  registry_credential {
    source {
      login_mode = "None"
    }
    custom {
      login_server = azurerm_container_registry.env.login_server
      identity     = "[system]"
    }
  }
}

resource "azurerm_container_registry_task" "build" {
  name                  = "radix-image-builder-build"
  container_registry_id = azurerm_container_registry.env.id
  platform {
    os           = "Linux"
    architecture = "amd64"
  }
  agent_setting {
    cpu = 2
  }

  base_image_trigger {
    enabled                     = true
    name                        = "defaultBaseimageTriggerName"
    type                        = "Runtime"
    update_trigger_payload_type = "Default"
  }
  tags = {
    IaC = "terraform"
  }
  encoded_step {
    task_content = <<EOF
  version: v1.1.0
  stepTimeout: 3600
  steps:
    - build: >-
        --tag {{.Values.IMAGE}}
        --tag {{.Values.CLUSTERTYPE_IMAGE}}
        --tag {{.Values.CLUSTERNAME_IMAGE}}
        --file {{.Values.DOCKER_FILE_NAME}}
        .
        {{.Values.BUILD_ARGS}}
  EOF
  }
  identity {
    type = "SystemAssigned"
  }
  registry_credential {
    source {
      login_mode = "None"
    }
    custom {
      login_server = azurerm_container_registry.env.login_server
      identity     = "[system]"
    }
  }
}

resource "azurerm_role_assignment" "env" {
  scope                = azurerm_container_registry.env.id
  role_definition_name = "Contributor"
  principal_id         = var.radix_cr_cicd
}

resource "azurerm_private_endpoint" "env" {
  name                = var.acr == "c2" ? "pe-radix-acr-c2prod" : "pe-radix-acr-${var.acr}"
  resource_group_name = var.vnet_resource_group
  location            = var.location
  subnet_id           = var.subnet_id
  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_container_registry.env.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_private_dns_a_record" "env" {
  for_each = {
    for k, v in azurerm_private_endpoint.env.custom_dns_configs : v.fqdn => v
  }
  name                = replace(each.key, ".azurecr.io", "")
  zone_name           = "privatelink.azurecr.io"
  resource_group_name = var.vnet_resource_group
  ttl                 = 300
  records             = toset(each.value.ip_addresses)
  tags = {
    IaC = "terraform"
  }
  depends_on = [azurerm_private_endpoint.env]
}

resource "azurerm_management_lock" "env" {
  name       = "delete-lock"
  scope      = azurerm_container_registry.env.id
  lock_level = "CanNotDelete"
  notes      = "IaC : Terraform"
}

#Cache
resource "azurerm_container_registry" "cache" {
  name                = "radix${var.acr}cache" == "radixprodcache" ? "radixplatformcache" : "radix${var.acr}cache"
  resource_group_name = var.common_res_group
  location            = var.location
  sku                 = "Premium"
  tags = {
    IaC = "terraform"
  }

  network_rule_set {
    default_action = "Deny"
    ip_rule = [
      {
        action   = "Allow"
        ip_range = var.ip_rule
      },
      {
        action   = "Allow"
        ip_range = "185.55.105.28"
      }
    ]
  }

}

resource "azurerm_container_registry_cache_rule" "cache" {
  for_each              = var.cacheregistry
  name                  = each.key
  container_registry_id = azurerm_container_registry.cache.id
  target_repo           = each.value.namespace
  source_repo           = "${each.value.repo}/${each.value.library}"
  credential_set_id     = each.value.repo == "docker.io" ? var.dockercredentials_id : null
}

resource "azurerm_private_endpoint" "cache" {
  name                = "pe-radix-acr-cache-${var.acr}"
  resource_group_name = var.vnet_resource_group
  location            = var.location
  subnet_id           = var.subnet_id
  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_container_registry.cache.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_private_dns_a_record" "cache" {
  for_each = {
    for k, v in azurerm_private_endpoint.cache.custom_dns_configs : v.fqdn => v #if length(regexall("\\.", v.fqdn)) >= 3
  }
  name                = replace(each.key, ".azurecr.io", "")
  zone_name           = "privatelink.azurecr.io"
  resource_group_name = var.vnet_resource_group
  ttl                 = 300
  records             = toset(each.value.ip_addresses)
  tags = {
    IaC = "terraform"
  }
  depends_on = [azurerm_private_endpoint.cache]
}

resource "azurerm_management_lock" "cache" {
  name       = "delete-lock"
  scope      = azurerm_container_registry.cache.id
  lock_level = "CanNotDelete"
  notes      = "IaC : Terraform"
}

output "azurerm_container_registry_id" {
  value = azurerm_container_registry.env.id
}

output "azurerm_container_registry_cache_id" {
  value = azurerm_container_registry.cache.id
}

output "azurerm_container_registry_app_id" {
  value = azurerm_container_registry.this.id
}