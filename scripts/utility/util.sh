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
    printf "\nVerifying cluster access..\n"
    kubectl cluster-info || {
      printf "ERROR: Could not access cluster. Quitting...\n"
      exit 1
    }
      
    printf " OK\n"
}