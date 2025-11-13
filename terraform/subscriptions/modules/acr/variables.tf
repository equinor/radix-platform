variable "acr" {
  description = "ACR name"
  type        = string
}

variable "location" {
  description = "The Azure Region where the Backup Vault should exist."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group where the Backup Vault should exist"
  type        = string
}

variable "virtual_network" {
  type    = string
  default = "vnet-hub"
}

variable "vnet_resource_group" {
  type = string
}

variable "subnet_id" {
  description = "A list of virtual network subnet ids to secure the storage account."
  type        = string
}

variable "dockercredentials_id" {
  type    = string
  default = null
}

variable "cacheregistry" {
  type = map(object({
    namespace = string
    library   = string
    repo      = string
  }))
  default = {
    alpine = {
      namespace = "alpine"
      library   = "library/alpine"
      repo      = "docker.io"
    }
    alpinegit = {
      namespace = "alpine/git"
      library   = "alpine/git"
      repo      = "docker.io"
    }
    bitnamishell = {
      namespace = "bitnami/bitnami-shell"
      library   = "bitnami/bitnami-shell"
      repo      = "docker.io"
    }
    bash-shell = {
      namespace = "bash"
      library   = "library/bash"
      repo      = "docker.io"
    }
    kubectl = {
      namespace = "bitnami/kubectl"
      library   = "bitnami/kubectl"
      repo      = "docker.io"
    }
    grafana = {
      namespace = "grafana/grafana"
      library   = "grafana/grafana"
      repo      = "docker.io"
    }
    velero = {
      namespace = "velero/velero"
      library   = "velero/velero"
      repo      = "docker.io"
    }
    velero-plugin-for-microsoft-azure = {
      namespace = "velero/velero-plugin-for-microsoft-azure"
      library   = "velero/velero-plugin-for-microsoft-azure"
      repo      = "docker.io"
    }
    alertmanager = {
      namespace = "prometheus/alertmanager"
      library   = "prometheus/alertmanager"
      repo      = "quay.io"
    }
    buildah = {
      namespace = "buildah/stable"
      library   = "buildah/stable"
      repo      = "quay.io"
    }
    cert-manager-cainjector = {
      namespace = "jetstack/cert-manager-cainjector"
      library   = "jetstack/cert-manager-cainjector"
      repo      = "quay.io"
    }
    cert-manager-controller = {
      namespace = "jetstack/cert-manager-controller"
      library   = "jetstack/cert-manager-controller"
      repo      = "quay.io"
    }
    cert-manager-startupapicheck = {
      namespace = "jetstack/cert-manager-startupapicheck"
      library   = "jetstack/cert-manager-startupapicheck"
      repo      = "quay.io"
    }
    cert-manager-webhook = {
      namespace = "jetstack/cert-manager-webhook"
      library   = "jetstack/cert-manager-webhook"
      repo      = "quay.io"
    }
    cert-manager-acmesolver = {
      namespace = "jetstack/cert-manager-acmesolver"
      library   = "jetstack/cert-manager-acmesolver"
      repo      = "quay.io"
    }
    kubernetes-replicator = {
      namespace = "mittwald/kubernetes-replicator"
      library   = "mittwald/kubernetes-replicator"
      repo      = "quay.io"
    }
    node-exporter = {
      namespace = "prometheus/node-exporter"
      library   = "prometheus/node-exporter"
      repo      = "quay.io"
    }
    oauth2-proxy = {
      namespace = "oauth2-proxy/oauth2-proxy"
      library   = "oauth2-proxy/oauth2-proxy"
      repo      = "quay.io"
    }
    prometheus = {
      namespace = "prometheus/prometheus"
      library   = "prometheus/prometheus"
      repo      = "quay.io"
    }
    prometheus-config-reloader = {
      namespace = "prometheus-operator/prometheus-config-reloader"
      library   = "prometheus-operator/prometheus-config-reloader"
      repo      = "quay.io"
    }
    prometheus-operator = {
      namespace = "prometheus-operator/prometheus-operator"
      library   = "prometheus-operator/prometheus-operator"
      repo      = "quay.io"
    }
    redis = {
      namespace = "library/redis"
      library   = "library/redis"
      repo      = "docker.io"
    }
  }
}

variable "radix_cr_cicd" {
  type        = string
  description = "ID of radix-cr Contributor"
}

variable "public_network_access" {
  type    = bool
  default = false
}

variable "acr_retension_policy" {
  type    = number
  default = 0
}

variable "keyvault_name" {
  type = string
}

variable "secondary_location" {
  type = string
}

variable "testzone" {
  type    = bool
  default = false
}

variable "abac_this" {
  description = "Enable ABAC repository permissions on APP container registry instead of legacy registry permissions."
  type = bool
  default = false
}

variable "abac_env" {
  description = "Enable ABAC repository permissions mode for the main container container registry instead of legacy registry permissions."
  type    = bool
  default = false
}

variable "abac_cache" {
  description = "Enable ABAC repository permissions mode for the cache container registry instead of legacy registry permissions."
  type    = bool
  default = false
}

