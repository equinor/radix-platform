#!/usr/bin/env bash

function get_credentials () {
    printf "\nRunning az aks get-credentials...\n"
    local AZ_RESOURCE_GROUP_CLUSTERS="$1"
    local CLUSTER="$2"
  
    az aks get-credentials  \
    --overwrite-existing  \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"  \
    --name "$CLUSTER" \
    --format exec \
    || { return; }
    # TODO: if we get ResourceNotFound, don't print message. if we get any other error, like instructions to log in with browser, do print error
}

function verify_cluster_access() {
    printf "\nVerifying cluster access...\n"
    kubectl cluster-info || {
      printf "ERROR: Could not access cluster. Quitting...\n"
      exit 1
    }
    printf " OK\n"
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