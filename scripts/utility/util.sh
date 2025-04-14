#!/usr/bin/env bash

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

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
  elif [[ $env == "prod" ]] || [[ $env == "c2" ]] || [[ $env == "extmon" ]] ; then
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
  elif [[ $RADIX_ZONE == "prod" ]] || [[ $RADIX_ZONE == "c2" ]] || [[ $RADIX_ZONE == "extmon" ]] ; then
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
  local json=$(cat <<EOF
  {
    "cluster_rg": "$az_resource_group_clusters",
    "common_rg": "$az_resource_group_common",
    "velero_sa": "$velero_storage_account",
    "keyvault" : "$keyvault_name",
    "dnz_zone": "$dns_zone_name",
    "acr": "$imageRegistry",
    "egress_prefix": "$ip_prefix_egress",
    "ingress_prefix": "$ip_prefix_ingress"
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

function get_cluster_outbound_ip() {
    local migration_strategy=$1
    local cluster_name=$2
    local az_subscription_id=$3
    local az_ipre_outbound_name=$4
    local az_resource_group_common=$5
    local ip_prefix

    if [[ "${migration_strategy}" == "at" ]]; then
        ip_address=$(get_test_cluster_outbound_ip $cluster_name $az_subscription_id)
        if [[ -z "${ip_address}" ]]; then
          printf "ERROR: Could not get outbound IP address for test cluster $cluster_name.\n" >&2
          return 1
        fi
        ip_prefix="$ip_address/32"
    else
        ip_prefix=$(az network public-ip prefix show \
            --name "${az_ipre_outbound_name}" \
            --resource-group "${az_resource_group_common}" \
            --subscription "${az_subscription_id}" \
            --query "ipPrefix" \
            --output tsv)
    fi
    echo $ip_prefix
}

function get_test_cluster_outbound_ip() {
    local dest_cluster=$1
    local az_subscription_id=$2

    json_output_file="/tmp/$(uuidgen)"
    az network lb list --subscription ${az_subscription_id} | jq '[.[] | select(.tags | contains ({"aks-managed-cluster-name": "'${dest_cluster}'"}) )]' > $json_output_file
    if [[ $(jq length $json_output_file) != "1" ]]; then
        printf "ERROR: Expected exactly 1 LB associated with cluster $dest_cluster, but found $(jq length $json_output_file)" >&2
        rm $json_output_file $outbound_rules_file $frontend_ip_configurations_file
        return 1
    fi
    outbound_rules_file="/tmp/$(uuidgen)"
    cat $json_output_file | jq -r .[0].outboundRules > $outbound_rules_file
    if [[ $(jq length $outbound_rules_file) != "1" ]]; then
        printf "ERROR: Expected exactly 1 outbound rule associated with LB in $dest_cluster, but found $(jq length $outbound_rules_file)" >&2
        rm $json_output_file $outbound_rules_file $frontend_ip_configurations_file
        return 1
    fi
    frontend_ip_configurations_file="/tmp/$(uuidgen)"
    cat $outbound_rules_file | jq -r .[0].frontendIPConfigurations > $frontend_ip_configurations_file
    if [[ $(jq length $frontend_ip_configurations_file) != "1" ]]; then
        printf "ERROR: Expected exactly 1 frontendIPConfiguration associated with outbound rule in LB for $dest_cluster, but found $(jq length $frontend_ip_configurations_file)" >&2
        rm $json_output_file $outbound_rules_file $frontend_ip_configurations_file
        return 1
    fi
    frontend_ip_configurations_id=$(cat $frontend_ip_configurations_file | jq -r .[0].id)
    ip_address_resource_id=$(az resource show --id $frontend_ip_configurations_id --query properties.publicIPAddress.id -o tsv)
    echo $(az resource show --id $ip_address_resource_id --query properties.ipAddress -o tsv)

    rm $json_output_file $outbound_rules_file $frontend_ip_configurations_file
}

function check_staging_certs(){
    echo ""
    if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        dl_certs=()
        root_certs=("https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem" "https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x2.pem")
        count_dl_root_certs=$(echo "${#root_certs[@]}")
        search_dir=/usr/local/share/ca-certificates
        i=0

        #Download latest stage root certs and do md5sum of each into array
        for cert in ${root_certs[@]}; do
            temp_file_path="/tmp/$(uuidgen)"
            curl -s $cert -o $temp_file_path
            md5=($(md5sum ${temp_file_path}))
            dl_certs+=("${md5}")
            rm ${temp_file_path}
        done

        #Compare installed certs with array of downloaded certs
        for file in "$search_dir"/*
        do
            j=0
            md5=($(md5sum ${file}))
            for item in "${dl_certs[@]}"; do
                if [[ $md5 == "$item" ]];then
                    ((i=i+1))
                    unset -v 'dl_certs[$j]'
                fi
            ((j=j+1))
            done
        done

        #Lets do the math
        if [[ $i -lt $count_dl_root_certs ]]; then
            echo "It seems that you dont have the staging root certs installed in $search_dir"
            echo "Visit https://letsencrypt.org/docs/staging-environment/#root-certificates and download the $count_dl_root_certs root certs, and install them in the path above."
            echo "Next you need to run: sudo update-ca-certificates"
            exit 0
        fi
    fi
}

get_latest_release() {
  # retrieves latest release version from a GitHub repository. Assumes the version has format v<version>.<major_version>.<minor_version>
  # this function does not use the more convenient GitHub API in order to circumvent rate limiting
  curl -sL https://github.com/$1/releases/latest | grep -E "/tree/" | grep -E "v[0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}" -o | head -1
}
