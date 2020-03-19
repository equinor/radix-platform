#!/bin/bash

#######################################################################################
### PURPOSE
###

# Recycle nodes in a cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Name of the cluster

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - NODE_POOL_NAME      : Name of the nodepool
# - NODE_NAME           : Name of the node to recycle. If not provided, then all will be recycled

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 ./recycle.sh

#######################################################################################
### START
###

echo ""
echo "Start recycle node(s)... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting... " >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting... " >&2
    exit 1
}
printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$RADIX_ZONE_ENV"

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$NODE_POOL_NAME" ]]; then
    NODE_POOL_NAME=nodepool1
fi

if [[ -z "$NODE_NAME" ]]; then
    NODE_NAME=All
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap AKS will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  NODE_NAME                        : $NODE_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $AZ_SUBSCRIPTION"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
        echo ""
        echo "Quitting."
        exit 0
    fi
    echo ""
fi

echo ""

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo ""
echo "Connecting kubectl to cluster..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then
    # Send message to stderr
    echo -e "Error: Cluster \"$DEST_CLUSTER\" not found." >&2
    exit 0
fi

function get_scaleset_instance_number() {
    local nodeName="${1}"

    nodeNameElements=($(echo "$nodeName" | awk '{split($0,a,"-"); print a[1],a[2],a[3],a[4]}'))

    instanceNumberString="${nodeNameElements[3]: -6}"
    instanceNumber=$(expr $instanceNumberString + 0)
    echo "$instanceNumber"
}

function get_scaleset_instance_name() {
    local nodeName="${1}"

    nodeNameElements=($(echo "$nodeName" | awk '{split($0,a,"-"); print a[1],a[2],a[3],a[4]}'))
    instanceNumber=$(get_scaleset_instance_number $nodeName)

    instanceName="${nodeNameElements[0]}-${nodeNameElements[1]}-${nodeNameElements[2]}-vmss_${instanceNumber}"
    echo -e "$instanceName"
    echo -e ""

}

function recycle_scalesetinstance() {
    local nodeName="${1}"

    scaleSetResourceGroup="MC_${AZ_RESOURCE_GROUP_CLUSTERS}_${CLUSTER_NAME}_${AZ_RADIX_ZONE_LOCATION}"
    scaleSet=($(az vmss list --subscription "$AZ_SUBSCRIPTION" -g "$scaleSetResourceGroup" --query [].name -o tsv))

    scaleSetInstance=$(get_scaleset_instance_name $nodeName)

    for scaleset in "${scaleSet[@]}"; do
        scaleSetInstances=($(az vmss list-instances --subscription "$AZ_SUBSCRIPTION" -g "$scaleSetResourceGroup" --name "$scaleset" --query [].name -o tsv))

        for instances in "${scaleSetInstances[@]}"; do
            if [[ $scaleSetInstance == $instances ]]; then
                instanceNumber=$(get_scaleset_instance_number $nodeName)

                echo -e "Deleting instance number $instanceNumber"
                echo -e ""
                az vmss delete-instances --instance-ids "$instanceNumber" --subscription "$AZ_SUBSCRIPTION" -g "$scaleSetResourceGroup" --name "$scaleset"
            fi
        done
    done
}

function recycle_node() {
    local node="${1}"

    echo -e "Draining $node"
    kubectl drain "$node" --ignore-daemonsets --delete-local-data
    recycle_scalesetinstance "$node"
}

NUM_NODES_IN_CLUSTER="$(kubectl get nodes --no-headers | wc -l | tr -d '[:space:]')"
ALL_NODES=($(kubectl get nodes -o custom-columns=':metadata.name' --no-headers))

for node in "${ALL_NODES[@]}"; do
    if [[ $NODE_NAME == All ]]; then
        recycle_node $node

        echo -e "Scaling cluster back to original size"
        az aks nodepool scale --cluster-name "$CLUSTER_NAME" --name "$NODE_POOL_NAME" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --node-count "$NUM_NODES_IN_CLUSTER"

    elif [[ $NODE_NAME == $node ]]; then
        recycle_node $node

        echo -e "Scaling cluster back to original size"
        az aks nodepool scale --cluster-name "$CLUSTER_NAME" --name "$NODE_POOL_NAME" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --node-count "$NUM_NODES_IN_CLUSTER"
    fi
done
