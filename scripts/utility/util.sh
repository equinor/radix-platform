#!/usr/bin/env bash

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function dr_zone_message() {
  local env="$1"
  echo "As MODE=DR is requested, you need to temporarily alter some code."
  echo "Please examine the functions config_path() and environment_json() in util.sh."
  echo "Prepare these functions for an alternate zone and/or subscription."
  echo ""
  echo "\$env must be set to $env, and you need to specify the subscription (e.g., s612)."
  echo ""
  
  while true; do
    read -r -p "If this is already done, press Yes (Y/n): " yn
    case $yn in
      [Yy]*) break ;;
      [Nn]*)
        echo ""
        echo "Quitting."
        exit 0
        ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
  
  echo ""
}

function check_secrets_exist() {
    local keyvault_name="$1"
    shift
    local keys=("$@")
    local missing_secrets=()
    
    for key in "${keys[@]}"; do
        if ! az keyvault secret show --vault-name "$keyvault_name" --name "$key" &>/dev/null; then
            missing_secrets+=("$key")
        fi
    done
    
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        echo "ERROR: Missing secrets in Key Vault '$keyvault_name': ${missing_secrets[*]}" >&2
        return 1
    fi
    
    return 0
}


function config_path() {
  local env="$1"
  RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
  if [[ $env == "dev" ]] || [[ $env == "playground" ]]; then
    if [[ ! -f "$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/s941/$env/config.yaml" ]]; then
      echo "ERROR: RADIX_ZONE=$env is invalid, the file does not exist." >&2
      exit 1
    else
      echo "$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/s941/$env/config.yaml"
    fi
  elif [[ $env == "prod" ]] || [[ $env == "c2" ]] || [[ $env == "c3" ]] || [[ $env == "extmon" ]] ; then
    if [[ ! -f "$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/s940/$env/config.yaml" ]]; then
      echo "ERROR: RADIX_ZONE=$env is invalid, the file does not exist." >&2
      exit 1
    else
      echo "$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/s940/$env/config.yaml"
    fi
  fi
}

function environment_json() {
  local RADIX_ZONE="$1"
  RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
  if [[ $RADIX_ZONE == "dev" ]] || [[ $RADIX_ZONE == "playground" ]]; then
    local AZ_SUBSCRIPTION_NAME="s941"
  elif [[ $RADIX_ZONE == "prod" ]] || [[ $RADIX_ZONE == "c2" ]] || [[ $RADIX_ZONE == "c3" ]] || [[ $RADIX_ZONE == "extmon" ]] ; then
    local AZ_SUBSCRIPTION_NAME="s940"
  fi
  local terraform=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" init) >&2
  local az_resource_group_clusters=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw az_resource_group_clusters)
  local az_resource_group_common=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw az_resource_group_common)
  local velero_storage_account=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw velero_storage_account)
  local keyvault_name=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw keyvault_name)
  local dns_zone_name=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw dns_zone_name)
  local imageRegistry=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw imageRegistry)
  local ip_prefix_egress=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -json public_ip_prefix_names | jq -r .egress)
  local ip_prefix_ingress=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -json public_ip_prefix_names | jq -r .ingress)
  local ip_prefix_egress_ips=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw egress_ips)
  local radix_id_certmanager_mi_client_id=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw radix_id_certmanager_mi_client_id)
  local dns_zone_resource_group=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw dns_zone_resource_group)
  local json=$(cat <<EOF
  {
    "cluster_rg": "$az_resource_group_clusters",
    "common_rg": "$az_resource_group_common",
    "velero_sa": "$velero_storage_account",
    "keyvault" : "$keyvault_name",
    "dnz_zone": "$dns_zone_name",
    "acr": "$imageRegistry",
    "egress_prefix": "$ip_prefix_egress",
    "ingress_prefix": "$ip_prefix_ingress",
    "ip_prefix_egress_ips": "$ip_prefix_egress_ips",
    "radix_id_certmanager_mi_client_id": "$radix_id_certmanager_mi_client_id",
    "dns_zone_resource_group": "$dns_zone_resource_group"
  }
EOF
)
echo "$json"
}

function get_credentials() {
    printf "\nRunning az aks get-credentials...\n"
    local AZ_RESOURCE_GROUP_CLUSTERS="$1"
    local CLUSTER="$2"

    az aks get-credentials \
        --overwrite-existing \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --name "$CLUSTER" \
        --only-show-errors ||
        { return; }
    kubelogin convert-kubeconfig -l azurecli
    # TODO: if we get ResourceNotFound, don't print message. if we get any other error, like instructions to log in with browser, do print error
}
function get_credentials_silent() {
    local AZ_RESOURCE_GROUP_CLUSTERS="$1"
    local CLUSTER="$2"

    az aks get-credentials \
        --overwrite-existing \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --name "$CLUSTER"
        { return; }
    kubelogin convert-kubeconfig -l azurecli
    # TODO: if we get ResourceNotFound, don't print message. if we get any other error, like instructions to log in with browser, do print error
}

function verify_cluster_access() {
    if [[ -n $CI ]]; then return; fi
    printf "\nVerifying cluster access...\n"
    kubectl cluster-info || {
        printf "ERROR: Could not access cluster. Quitting...\n"
        exit 1
    }
    printf " OK\n"
}

function setup_cluster_access() {
  local AZ_RESOURCE_GROUP_CLUSTERS="$1"
  local CLUSTER_NAME="$2"

  get_credentials_silent "${AZ_RESOURCE_GROUP_CLUSTERS}" "${CLUSTER_NAME}"
  kubectl_context="$(kubectl config current-context)"
  if [ "${kubectl_context}" = "${CLUSTER_NAME}" ]; then
      return 0
  else
      echo "ERROR: Please set your kubectl current-context to be ${CLUSTER_NAME}"
      exit 1
  fi

  kubectl cluster-info > /dev/null || {
      echo "ERROR: Could not access cluster. Quitting..."
      exit 1
  }

  exit 0;
}

get_latest_release() {
  # retrieves latest release version from a GitHub repository. Assumes the version has format v<version>.<major_version>.<minor_version>
  # this function does not use the more convenient GitHub API in order to circumvent rate limiting
  curl -sL https://github.com/$1/releases/latest | grep -E "/tree/" | grep -E "v[0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}" -o | head -1
}

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

function check_installed_components() {
  echo ""
  printf "Check for neccesary executables... \n"
  hash az 2>/dev/null || {
      echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
      exit 1
  }

  AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
  MIN_AZ_CLI="2.57.0"
  if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
      printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI."${normal}"\n"
      exit 1
  fi

  hash cilium 2>/dev/null || {
      echo -e "\nERROR: cilium not found in PATH. Exiting..." >&2
      exit 1
  }

  hash jq 2>/dev/null || {
      echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
      exit 1
  }

  hash yq 2>/dev/null || {
      echo -e "\nERROR: yq not found in PATH. Exiting..." >&2
      exit 1
  }

  hash kubectl 2>/dev/null || {
      echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
      exit 1
  }

  hash envsubst 2>/dev/null || {
      echo -e "\nERROR: envsubst not found in PATH. Exiting..." >&2
      exit 1
  }

  hash helm 2>/dev/null || {
      echo -e "\nERROR: helm not found in PATH. Exiting..." >&2
      exit 1
  }

  hash velero 2>/dev/null || {
      echo -e "\nERROR: velero not found in PATH. Exiting..." >&2
      exit 1
  }

  hash htpasswd 2>/dev/null || {
      echo -e "\nERROR: htpasswd not found in PATH. Exiting..." >&2
      exit 1
  }

  hash flux 2>/dev/null || {
      echo -e "\nERROR: flux not found in PATH. Exiting... " >&2
      exit 1
  }
  REQ_FLUX_VERSION="2.7.5"
  FLUX_VERSION=$(flux --version | awk '{print $3'})
  if [[ "$FLUX_VERSION" != "${REQ_FLUX_VERSION}" ]]; then
      printf ""${yel}"Please update flux cli to ${REQ_FLUX_VERSION}. You got version $FLUX_VERSION${normal}\n"
      exit 1
  fi


  hash sqlcmd 2>/dev/null || {
      echo -e "\nERROR: sqlcmd not found in PATH. Exiting... " >&2
      exit 1
  }

  hash kubelogin 2>/dev/null || {
      echo -e "\nERROR: kubelogin not found in PATH. Exiting... " >&2
      exit 1
  }

  hash uuidgen 2>/dev/null || {
      echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
      exit 1
  }

  hash terraform 2>/dev/null || {
      echo -e "\nERROR: terraform not found in PATH. Exiting..." >&2
      exit 1
  }

  printf "Done.\n"  
}