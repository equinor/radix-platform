#!/usr/bin/env bash


function get_credentials () {
    local AZ_RESOURCE_GROUP_CLUSTERS="$1"
    local CLUSTER="$2"
  
    az aks get-credentials  \
    --overwrite-existing  \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"  \
    --name "$CLUSTER" \
    --format exec \
    2>&1 || { return; }
  
}


function verify_cluster_access() {
printf "Verifying cluster access..."
kubectl cluster-info || {
  printf "ERROR: Could not access cluster. Quitting...\n"
  exit 1
}
  
printf " OK\n"
}