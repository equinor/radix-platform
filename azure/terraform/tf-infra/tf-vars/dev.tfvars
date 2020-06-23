location            = "northeurope"
aks_resource_group_name = "clusters"
# aks_name            = "weekly-13"
aks_dns_name        = "dev.radix.equinor.com"
kubernetes_version  = "1.16.9"
cluster_size        = "1"
vm_size             = "Standard_D1_v2"
environment         = "dev"

# Following are injected from the pipeline
# aks_sp_id           = ""
# aks_sp_secret       = ""
# aks_name            = ""