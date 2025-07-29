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
    # Infrastructure: Networking
    vnet_contributor = {
      role     = "Network Contributor" # Manage virtual networks, subnets, peerings, NSGs
      scope_id = module.resourcegroup_vnet.data.id
    }
    networking_contributor = {
      role     = "Network Contributor" # Same role, used in cluster RG
      scope_id = module.resourcegroup_clusters.data.id
    }
    networking_contributor_legacy = {
      role     = "Network Contributor"                        # Same role, used in cluster RG
      scope_id = "${data.azurerm_resource_group.clusters.id}" #TODO
    }
    networkwatcher_contributor = {
      role     = "Contributor" # Needed to manage flow logs in Network Watcher
      scope_id = data.azurerm_resource_group.networkwatcher.id
    }
    # Identity and Access
    managed_identity_contributor_common = {
      role     = "Managed Identity Contributor" # Assign and manage User Assigned Managed Identities (Common RG)
      scope_id = module.resourcegroup_common.data.id
    }
    managed_identity_contributor_cluster = {
      role     = "Managed Identity Contributor" # Assign and manage UAMIs in Cluster RG
      scope_id = module.resourcegroup_clusters.data.id
    }
    managed_identity_contributor_cluster_legacy = {
      role     = "Managed Identity Contributor"               # Assign and manage UAMIs in Cluster RG
      scope_id = "${data.azurerm_resource_group.clusters.id}" #TODO
    }
    vulnerability_scan_identity_contributor = {
      role     = "Managed Identity Contributor" # For identity used in vulnerability scan
      scope_id = module.resourcegroup_vulnerability_scan.data.id
    }
    cost_allocation_identity_contributor = {
      role     = "Managed Identity Contributor" # For identity used in cost allocation
      scope_id = module.resourcegroup_cost_allocation.data.id
    }
    grafana_identity_contributor = {
      role     = "Managed Identity Contributor" # For Grafana Managed Identity
      scope_id = data.azurerm_resource_group.monitoring.id
    }
    # App Configuration
    app_configuration_reader = {
      role     = "App Configuration Data Reader" # Read app config values (data plane)
      scope_id = module.keyvault.azurerm_app_configuration_id
    }
    app_configuration_contributor = {
      role     = "App Configuration Contributor" # Manage app config + list keys (control plane)
      scope_id = module.keyvault.azurerm_app_configuration_id
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
    monitoring_contributor_legacy = {
      role     = "Monitoring Contributor"                     # Manage alerts, metric rules, diagnostic settings, DCRs
      scope_id = "${data.azurerm_resource_group.clusters.id}" #TODO
    }
    # Kubernetes & DNS
    kubernetes_contributor = {
      role     = "Azure Kubernetes Service Contributor Role" # Manage AKS clusters (not cluster RBAC)
      scope_id = module.resourcegroup_clusters.data.id
    }
    kubernetes_contributor_legacy = {
      role     = "Azure Kubernetes Service Contributor Role"  # Manage AKS clusters (not cluster RBAC)
      scope_id = "${data.azurerm_resource_group.clusters.id}" #TODO
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
    lock_operator = {
      role     = "Locks Contributor"
      scope_id = "${data.azurerm_resource_group.clusters.id}" #TODO
    }
  }
  federated_credentials = {
    radix-id-gitrunner = {
      name    = "radix-id-gitrunner-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix:environment:${module.config.environment}"
    },
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:environment:${module.config.environment}"
    }
  }
}