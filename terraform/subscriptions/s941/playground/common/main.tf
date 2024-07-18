module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.common_resource_group
  location = module.config.location
}

module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${module.config.environment}"
  resource_group_name           = module.config.common_resource_group
  location                      = module.config.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

data "azurerm_virtual_network" "this" {
  name                = "vnet-hub"
  resource_group_name = module.config.vnet_resource_group
}

data "azurerm_key_vault_secret" "this" {
  name         = "storageaccounts-ip-rule"
  key_vault_id = module.config.backend.ip_key_vault_id
}

data "azurerm_subnet" "this" {
  name                 = "private-links"
  resource_group_name  = module.config.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.this.name
}

module "storageaccount" {
  source                   = "../../../modules/storageaccount"
  for_each                 = var.storageaccounts
  name                     = "radix${each.key}${module.config.environment}"
  tier                     = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  resource_group_name      = each.value.resource_group_name
  location                 = each.value.location
  environment              = module.config.environment
  kind                     = each.value.kind
  change_feed_enabled      = each.value.change_feed_enabled
  versioning_enabled       = each.value.versioning_enabled
  backup                   = each.value.backup
  subnet_id                = data.azurerm_subnet.this.id
  vnet_resource_group      = module.config.vnet_resource_group
  lifecyclepolicy          = each.value.lifecyclepolicy
  ip_rule                  = data.azurerm_key_vault_secret.this.value
  log_analytics_id         = module.loganalytics.workspace_id
}

module "acr" {
  source               = "../../../modules/acr"
  ip_rule              = data.azurerm_key_vault_secret.this.value
  location             = module.config.location
  resource_group_name  = "common" #TODO
  common_res_group     = module.config.common_resource_group
  acr                  = module.config.environment
  vnet_resource_group  = module.config.vnet_resource_group
  subnet_id            = data.azurerm_subnet.this.id
  dockercredentials_id = "/subscriptions/${module.config.subscription}/resourceGroups/${module.config.common_resource_group}/providers/Microsoft.ContainerRegistry/registries/radix${module.config.environment}cache/credentialSets/radix-service-account-docker"
}

module "radix-id-acr-workflows" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-acr-workflows-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = module.acr.azurerm_container_registry_id
    },
    acrpush = {
      role     = "AcrPush"
      scope_id = module.acr.azurerm_container_registry_id
    }
  }
  federated_credentials = {
    radix-acr-cleanup-release = {
      name    = "radix-acr-cleanup-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-acr-cleanup:ref:refs/heads/release"
    }
    radix-cluster-cleanup-release = {
      name    = "radix-cluster-cleanup-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cluster-cleanup:ref:refs/heads/release"
    },
    radix-cicd-canary-release = {
      name    = "radix-cicd-canary-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cicd-canary:ref:refs/heads/release"
    },
    radix-radix-vulnerability-scanner-release = {
      name    = "radix-radix-vulnerability-scanner-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-radix-vulnerability-scanner:ref:refs/heads/release"
    },
  }
}

#######################################################################################
### Temporary Private endpoint to dev ACR 
### TODO task
###
resource "azurerm_private_endpoint" "env" {
  name                = "pe-radix-acr-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  subnet_id           = data.azurerm_subnet.this.id
  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = module.config.backend.acr_dev_id #TODO
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
  resource_group_name = module.config.vnet_resource_group
  ttl                 = 300
  records             = toset(each.value.ip_addresses)
  tags = {
    IaC = "terraform"
  }

}
#######################################################################################


output "workspace_id" {
  value = module.loganalytics.workspace_id
}

output "log_storageaccount_id" {
  value = module.storageaccount["log"].data.id
}

output "acr_id" {
  value = module.acr.azurerm_container_registry_id
}
