#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap aks instance in a radix zone

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Keep name short due to Azure weirdness. Ex: "test-2", "weekly-93".

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - CREDENTIALS_FILE    : Path to credentials in the form of shell vars. See "Set credentials" for required key/value pairs.

#######################################################################################
### HOW TO USE
###

# When creating a test cluster
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 MIGRATION_STRATEGY=at ./bootstrap.sh

# When creating a cluster that will become an active cluster (creating a cluster in advance)
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 MIGRATION_STRATEGY=aa ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap aks instance... "

#######################################################################################
### Check for prerequisites binaries
###






AKS_USER_OPTIONS=(
    --cluster-name "c2-prod-25"
    --nodepool-name userpool1
    --resource-group "clusters-westeurope"
    --enable-cluster-autoscaler
    --kubernetes-version "1.25.6"
    --max-count "12"
    --max-pods "110"
    --min-count "6"
    --mode User
    --node-count "6"
    --node-osdisk-size "1024"
    # --node-vm-size "Standard_E16as_v4"
    --node-vm-size "Standard_E16s_v4"
    --vnet-subnet-id "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/clusters-westeurope/providers/Microsoft.Network/virtualNetworks/vnet-c2-prod-25/subnets/subnet-c2-prod-25"
)
echo "Create user nodepool"
az aks nodepool add "${AKS_USER_OPTIONS[@]}"

