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
    "ip_prefix_egress_ips": "$ip_prefix_egress_ips"
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
