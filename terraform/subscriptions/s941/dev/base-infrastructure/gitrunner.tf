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
    # Container Registry
    container_registry_app = {
      role     = "Contributor"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
    container_registry_app_abac_contributor = {
      role     = "Container Registry Repository Contributor"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
    container_registry_app_abac_lister = {
      role     = "Container Registry Repository Catalog Lister"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
    # Infrastructure: Networking
    k8s_command_runner = {
      role     = "Radix Azure Kubernetes Service Command Runner"
      scope_id = module.resourcegroup_clusters.data.id
    }
    cluster_vnet_hub = {
      role     = "Private DNS Zone Contributor"
      scope_id = module.resourcegroup_vnet.data.id
    }
    # vnet_contributor = {
    #   role     = "Network Contributor" # Manage virtual networks, subnets, peerings, NSGs
    #   scope_id = module.resourcegroup_vnet.data.id
    # }
    # networking_contributor = {
    #   role     = "Network Contributor" # Same role, used in cluster RG
    #   scope_id = module.resourcegroup_clusters.data.id
    # }
    # networkwatcher_contributor = {
    #   role     = "Contributor" # Needed to manage flow logs in Network Watcher
    #   scope_id = data.azurerm_resource_group.networkwatcher.id
    # }
    # # Identity and Access
    # managed_identity_contributor_common = {
    #   role     = "Managed Identity Contributor" # Assign and manage User Assigned Managed Identities (Common RG)
    #   scope_id = module.resourcegroup_common.data.id
    # }
    # managed_identity_contributor_cluster = {
    #   role     = "Managed Identity Contributor" # Assign and manage UAMIs in Cluster RG
    #   scope_id = module.resourcegroup_clusters.data.id
    # }
    # vulnerability_scan_identity_contributor = {
    #   role     = "Managed Identity Contributor" # For identity used in vulnerability scan
    #   scope_id = module.resourcegroup_vulnerability_scan.data.id
    # }
    # cost_allocation_identity_contributor = {
    #   role     = "Managed Identity Contributor" # For identity used in cost allocation
    #   scope_id = module.resourcegroup_cost_allocation.data.id
    # }
    # grafana_identity_contributor = {
    #   role     = "Managed Identity Contributor" # For Grafana Managed Identity
    #   scope_id = data.azurerm_resource_group.monitoring.id
    # }
    # # App Configuration
    # app_configuration_reader = {
    #   role     = "App Configuration Data Reader" # Read app config values (data plane)
    #   scope_id = module.keyvault.azurerm_app_configuration_id
    # }
    # app_configuration_contributor = {
    #   role     = "App Configuration Contributor" # Manage app config + list keys (control plane)
    #   scope_id = module.keyvault.azurerm_app_configuration_id
    # }
    # #  Monitoring & Logging
    # log_analytics_contributor = {
    #   role     = "Log Analytics Contributor" # Manage workspaces and access shared keys
    #   scope_id = module.resourcegroup_common.data.id
    # }
    # monitoring_contributor = {
    #   role     = "Monitoring Contributor" # Manage alerts, metric rules, diagnostic settings, DCRs
    #   scope_id = module.resourcegroup_clusters.data.id
    # }
    # # Kubernetes & DNS
    # kubernetes_contributor = {
    #   role     = "Azure Kubernetes Service Contributor Role" # Manage AKS clusters (not cluster RBAC)
    #   scope_id = module.resourcegroup_clusters.data.id
    # }
    # dns_zone_contributor = {
    #   role     = "DNS Zone Contributor" # Needed to manage DNS records
    #   scope_id = module.resourcegroup_common.data.id
    # }
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