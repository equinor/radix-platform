#!/usr/bin/env bash

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
# - DRY_RUN             : To run without the commands
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
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}
printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Read the cluster config that correspond to selected environment in the zone config.
source "$RADIX_ZONE_ENV"

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$DRY_RUN" ]]; then
    DRY_RUN=false
fi

if [[ -z "$NODE_NAME" ]]; then
    NODE_NAME=All
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
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
echo -e "   -  AZ_RESOURCE_GROUP_CLUSTERS       : $AZ_RESOURCE_GROUP_CLUSTERS"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  NODE_NAME                        : $NODE_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo ""
fi

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo ""
echo "Connecting kubectl to cluster..."

get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$DEST_CLUSTER\" not found." >&2
    exit 0
}

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Support funcs
###

function get_nodename_elements() {
    local nodeName="${1}"

    nodeNameElements=($(echo "$nodeName" | awk '{split($0,a,"-"); print a[1],a[2],a[3],a[4]}'))
    echo "${nodeNameElements[@]}"
}

function get_scaleset_instance_number() {
    local nodeName="${1}"

    nodeNameElements=($(get_nodename_elements "$nodeName"))
    instanceNumberString="${nodeNameElements[3]: -6}"
    instanceNumber=$(expr $instanceNumberString + 0)
    echo "$instanceNumber"
}

function get_scaleset_instance_name() {
    local nodeName="${1}"

    nodeNameElements=($(get_nodename_elements "$nodeName"))
    instanceNumber=$(get_scaleset_instance_number "$nodeName")

    instanceName="${nodeNameElements[0]}-${nodeNameElements[1]}-${nodeNameElements[2]}-vmss_${instanceNumber}"
    echo -e "$instanceName"
    echo -e ""

}

function get_nodepool_name() {
    local nodeName="${1}"

    nodeNameElements=($(get_nodename_elements "$nodeName"))
    instanceName="${nodeNameElements[0]}-${nodeNameElements[1]}-${nodeNameElements[2]}-vmss_${instanceNumber}"
    echo -e "${nodeNameElements[1]}"
}

function get_scaleset_resourcegroup() {
    scaleSetResourceGroup="MC_${AZ_RESOURCE_GROUP_CLUSTERS}_${CLUSTER_NAME}_${AZ_RADIX_ZONE_LOCATION}"
    echo "$scaleSetResourceGroup"
}

function get_scalesets() {
    scaleSetResourceGroup=$(get_scaleset_resourcegroup)
    scaleSets=($(az vmss list --subscription "$AZ_SUBSCRIPTION_ID" -g "$scaleSetResourceGroup" --query [].name -o tsv))
    echo "${scaleSets[@]}"
}

function recycle_scalesetinstance() {
    local nodeName="${1}"

    scaleSetInstance=$(get_scaleset_instance_name "$nodeName")

    scaleSetResourceGroup=$(get_scaleset_resourcegroup)
    scaleSets=($(get_scalesets))

    for scaleSet in "${scaleSets[@]}"; do
        scaleSetInstances=($(az vmss list-instances --subscription "$AZ_SUBSCRIPTION_ID" -g "$scaleSetResourceGroup" --name "$scaleSet" --query [].name -o tsv))

        for instance in "${scaleSetInstances[@]}"; do
            if [[ $scaleSetInstance == $instance ]]; then
                instanceNumber=$(get_scaleset_instance_number "$nodeName")

                echo -e "Deleting instance number $instanceNumber"
                if [[ $DRY_RUN == false ]]; then
                    az vmss delete-instances --instance-ids "$instanceNumber" --subscription "$AZ_SUBSCRIPTION_ID" -g "$scaleSetResourceGroup" --name "$scaleSet"
                fi

            fi
        done
    done
}

function recycle_node() {
    local node="${1}"

    echo -e "Draining $node"
    if [[ $DRY_RUN == false ]]; then
        kubectl cordon "$node"
        kubectl drain "$node" --force=true --ignore-daemonsets --delete-local-data
    fi
    recycle_scalesetinstance "$node"
}

#######################################################################################
### MAIN
###

allNodes=($(kubectl get nodes -o custom-columns=':metadata.name' --no-headers))

for node in "${allNodes[@]}"; do
    nodePool="$(get_nodepool_name "$node")"
    numNodesInNodepool="$(az aks nodepool show --cluster-name "$CLUSTER_NAME" --name "$nodePool" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --query count)"

    if [[ $NODE_NAME == All ]]; then
        echo -e ""
        echo -e "Recycle $node in $nodePool"

        recycle_node "$node"

        echo -e "Scaling $nodePool in cluster back to original size ($numNodesInNodepool)"
        if [[ $DRY_RUN == false ]]; then
            az aks nodepool scale --cluster-name "$CLUSTER_NAME" --name "$nodePool" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --node-count "$numNodesInNodepool" >/dev/null
        fi

        if [[ $USER_PROMPT == true ]]; then
            while true; do
                read -r -p "Continue to next node? (Y/n) " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo ""; echo "Quitting."; exit 0;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi

    elif [[ $NODE_NAME == $node ]]; then
        echo -e ""
        echo -e "Recycle $node in $nodePool"

        recycle_node "$node"

        echo -e "Scaling $nodePool in cluster back to original size ($numNodesInNodepool)"

        if [[ $DRY_RUN == false ]]; then
            az aks nodepool scale --cluster-name "$CLUSTER_NAME" --name "$nodePool" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --node-count "$numNodesInNodepool" >/dev/null
        fi
    fi
done

#######################################################################################
### END
###

echo -e ""
echo -e "Cluster is back to original size. New instances are:"
echo -e ""

scaleSetResourceGroup=$(get_scaleset_resourcegroup)
scaleSets=($(get_scalesets))

for scaleSet in "${scaleSets[@]}"; do
    scaleSetInstances=($(az vmss list-instances --subscription "$AZ_SUBSCRIPTION_ID" -g "$scaleSetResourceGroup" --name "$scaleSet" --query [].name -o tsv))
    for instances in "${scaleSetInstances[@]}"; do
        echo -e "  - $instances"
    done
done
