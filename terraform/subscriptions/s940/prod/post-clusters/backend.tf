terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.110.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "< 3.0.0"
    }
  }

  backend "azurerm" {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id      = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    key                  = "prod/post-clusters/terraform.tfstate"
    use_azuread_auth     = true # This enables RBAC instead of access keys
  }
}

provider "azurerm" {
  subscription_id     = "ded7ca41-37c8-4085-862f-b11d21ab341a"
  storage_use_azuread = true
  features {}
}

module "config" {
  source = "../../../modules/config"
}

module "clusters" {
  source              = "../../../modules/active-clusters"
  resource_group_name = "clusters" #TODO with code below after cluster in new RG module.config.cluster_resource_group
  subscription        = module.config.subscription
}

module "clusters_c1" {
  source              = "../../../modules/active-clusters"
  resource_group_name = "clusters-c1" #TODO
  subscription        = module.config.subscription
}

locals {
  oidc_issuer_urls = merge(
    module.clusters.oidc_issuer_url,
    try(module.clusters_c1.oidc_issuer_url, {})
  )
}

#TODO: Remove module.clusters_c1 and related code when all clusters have been migrated to new RGs and module.clusters can be used exclusively.
#Migration steps:
#1. Migrate cluster-c1 resource groups to module.clusters and remove from module.clusters_c1
#2. Replace local.oidc_issuer_urls with module.clusters.oidc_issuer_url and remove try for module.clusters_c1
#3. Migrate nsg rules and federated credentials to use module.clusters instead of module.clusters_c1 where applicable
#4. Replace nsg_ids with module.clusters.nsg and remove try for module.clusters_c1.nsg
#5. Update web-console.tf to iterate module.clusters.oidc_issuer_url instead of local.oidc_issuer_urls
#6. Remove nsg_resource_group_names usage in aks_security_rule.tf if all NSGs are in one default cluster resource group
#7. Revert modules/aks/nsg_rule/main.tf to use var.resource_group_name directly and remove nsg_resource_group_names variable

