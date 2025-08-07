module "radix_id_gitrunner" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    # Storage and Blob Access
    storage_account_contributor = {
      role     = "Storage Account Contributor" # Needed to manage Storage Account firewall and settings
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    storage_blob_data_contributor = {
      role     = "Storage Blob Data Contributor" # Needed to manage blobs and containers (read/write/delete data)
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    # Infrastructure: Networking
    vnet_contributor = {
      role     = "Network Contributor" # Manage virtual networks, subnets, peerings, NSGs
      scope_id = module.resourcegroup_vnet.data.id
    }
    networking_contributor = {
      role     = "Network Contributor" # Same role, used in cluster RG
      scope_id = module.resourcegroup_clusters.data.id
    }
    networkwatcher_contributor = {
      role     = "Contributor" # Needed to manage flow logs in Network Watcher
      scope_id = data.azurerm_resource_group.networkwatcher.id
    }
    #  Monitoring & Logging
    log_analytics_contributor = {
      role     = "Log Analytics Contributor" # Manage workspaces and access shared keys
      scope_id = module.resourcegroup_common.data.id
    }
    monitoring_contributor = {
      role     = "Monitoring Contributor" # Manage alerts, metric rules, diagnostic settings, DCRs
      scope_id = module.resourcegroup_clusters.data.id
    }
    # Kubernetes & DNS
    kubernetes_contributor = {
      role     = "Azure Kubernetes Service Contributor Role" # Manage AKS clusters (not cluster RBAC)
      scope_id = module.resourcegroup_clusters.data.id
    }
    dns_zone_contributor = {
      role     = "DNS Zone Contributor" # Needed to manage DNS records
      scope_id = module.resourcegroup_common.data.id
    }
    # Custom Roles
    privatelink-contributor = {
      role     = "Radix Privatelink rbac-${module.config.subscription_shortname}"
      scope_id = "/subscriptions/${module.config.subscription}"
    }
  }
  federated_credentials = {
    radix-id-gitrunner = {
      name    = "radix-id-gitrunner-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix:ref:refs/heads/main"
    },
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:ref:refs/heads/master"
    },
    radix-id-gitrunner-radix_pull = {
      name    = "radix-id-gitrunner-${module.config.environment}-radix_pull"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix:pull_request"
    }
  }
}