#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Upgrade the kubernetes version of a cluster. The control plane and the node pools need to be upgraded.


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Playground-47
# - TARGET_VERSION      : Target kubernetes version

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - CREDENTIALS_FILE    : Path to credentials in the form of shell vars. See "Set credentials" for required key/value pairs. 


#######################################################################################
### HOW TO USE
### 

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 TARGET_VERSION=1.19.9 ./upgrade.sh



#######################################################################################
### START
### 

echo ""
echo "Start upgrade of kubernetes version... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting... " >&2;  exit 1; }
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

if [[ -z "$TARGET_VERSION" ]]; then
    echo "Please provide TARGET_VERSION" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/${RADIX_ENVIRONMENT}.env"

# Optional inputs
if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$HUB_PEERING_NAME" ]]; then
    HUB_PEERING_NAME=hub-to-${CLUSTER_NAME}
fi

if [[ -z "$VNET_DNS_LINK" ]]; then
    VNET_DNS_LINK=$CLUSTER_NAME-link
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
echo -e "Upgrade script will use the following configuration:"
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
echo -e "   -  TARGET_VERSION                   : $TARGET_VERSION"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo -e ""

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
echo ""

# Every deployment needs to have more than 1 replica.
echo "Scale up deployments with only 1 replica."
# loop through namespaces
NAMESPACE="$(kubectl get namespace -oname  | sed 's\namespace/\\')"
ARR_EXCLUDE=( "kube-system" "velero" )

for NS in $NAMESPACE
do
    # exclude some namespaces
    if [[ " ${ARR_EXCLUDE[@]} " =~ " ${NS} " ]]; then
        echo "Skipping $NS."
    else
        # scale up the replica count
        # echo "Upscaling deployment $NS"
        this="not doing anything"
        # kubectl scale deployment --all --current-replicas=1 --replicas=2 --namespace $NS
    fi
done
echo "Deployments have been upscaled."

# get current nodes in all nodepools (before creating the temporary nodepool)
NODES="$(kubectl get nodes -oname | sed 's\node/\\')"

# For each populated nodepool, create a temporary nodepool
# NODEPOOL_NAMES="$(az aks nodepool list --cluster-name weekly-21 --resource-group clusters --query "[?count > \`0\`].name" --output json | jq --raw-output '.[].name')"
NODEPOOL_NAMES="$(az aks nodepool list --cluster-name $CLUSTER_NAME --resource-group clusters --query "[].name" --output json | jq --raw-output '.[]')"

for NODEPOOL_NAME in $NODEPOOL_NAMES
do
    # create temporary nodepool
    NODEPOOL_SIZE="$(az aks nodepool list --cluster-name weekly-21 --resource-group clusters --query "[?name == \`$NODEPOOL_NAME\`].vmSize" --output json | jq --raw-output '.[]')"
    echo "Creating temporary nodepool for: $NODEPOOL_NAME with $NODEPOOL_SIZE..."
    # az aks nodepool add --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --cluster-name $CLUSTER_NAME --node-vm-size $NODEPOOL_SIZE -name $NODEPOOL_NAME-temporary
done

echo "Drain nodes in existing nodepool(s)..."
# loop through nodes to drain
for NODE in $NODES
do
    # drain nodes in existing nodepool
    echo "Draining node $NODE..."
    # kubectl drain $NODE
done
echo "Nodes in existing nodepool(s) have been drained."

# upgrade existing nodepool
echo "Upgrade control plane..."
# az aks upgrade --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --name $CLUSTER_NAME --kubernetes-version $TARGET_VERSION --control-plane-only
echo "Control plane was upgraded."

# upgrade nodes in existing nodepool
echo "Upgrade existing nodepool..."
ALL_NODEPOOLS="$(az aks nodepool list --cluster-name weekly-21 --resource-group clusters --query "[].name" --output json)"
for NODEPOOL_NAME in $NODEPOOL_NAMES
do
    echo "Upgrading $NODEPOOL_NAME..."
    # az aks nodepool upgrade --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --cluster-name $CLUSTER_NAME --kubernetes-version $TARGET_VERSION --name $NODEPOOL_NAME
done

echo "Upgraded existing nodepool(s)."

# Loop through nodes to drain
NODES=( "aks-nodepool1-19036959-vmss000000" "aks-nodepool1-19036959-vmss000008" "aks-nodepool1-19036959-vmss00000a" "aks-nc12sv3-19036959-vmss000011" "aks-nc24sv3-19036959-vmss000021" "aks-nc6sv3-19036959-vmss000031" "aks-nc6sv3-19036959-vmss000033" ) # TESTING

echo "Drain nodes in temporary nodepool..."
NEW_NODES="$(kubectl get nodes -oname | sed 's\node/\\')"
NEW_NODES=( "aks-nodepool1-19036959-vmss000000" 
    "aks-nodepool1-19036959-vmss000008" 
    "aks-nodepool1-19036959-vmss00000a" 
    "aks-nc12sv3-19036959-vmss000011"
    "aks-nc24sv3-19036959-vmss000021"
    "aks-nc6sv3-19036959-vmss000031"
    "aks-nc6sv3-19036959-vmss000033"
    "aks-nodepool1-temporary-19036959-vmss000003" 
    "aks-nodepool1-temporary-19036959-vmss000004" 
    "aks-nodepool1-temporary-19036959-vmss000005"
    "aks-nc12sv3-temporary-19036959-vmss000012"
    "aks-nc24sv3-temporary-19036959-vmss000022"
    "aks-nc6sv3-temporary-19036959-vmss000032"
    "aks-nc6sv3-temporary-19036959-vmss000034" ) # TESTING

for NODE in ${NEW_NODES[@]}
do
    # Drain nodes in temporary nodepool
    if [[ " ${NODES[@]} " =~ $NODE ]]; then
        echo "Skipping $NODE"
    else
        echo "drain temporary node $NODE"
        # kubectl drain $NODE
    fi
done

# Delete temporary nodepool
echo "Delete temporary nodepool(s)..."
# az aks nodepool delete --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --cluster-name $CLUSTER_NAME --name temporary
echo "Temporary nodepool(s) deleted."