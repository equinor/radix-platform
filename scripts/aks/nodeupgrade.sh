#!/usr/bin/env bash
# Upgrade nodepool according to .env file
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-02 ./nodeupgrade.sh
#
# Upgrade nodepool with spesific Kubernetes version
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env KUBERNETES_VERSION="1.23.8" CLUSTER_NAME=weekly-02 ./nodeupgrade.sh

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

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

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Check if cluster or network resources are locked
###

printf "Checking for resource locks..."

CLUSTER=$(az aks list \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --query "[?name=='"${CLUSTER_NAME}"'].name" \
    --output tsv \
    --only-show-errors)

if [[ "${CLUSTER}" ]]; then
    CLUSTERLOCK="$(az lock list \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --resource-type Microsoft.ContainerService/managedClusters \
        --resource "$CLUSTER_NAME" \
        --query [].name \
        --output tsv \
        --only-show-errors)"
fi

VNET=$(az network vnet list \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --query "[?name=='"${VNET_NAME}"'].name" \
    --output tsv \
    --only-show-errors)

if [[ "${VNET}" ]]; then
    VNETLOCK="$(az lock list \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --resource-type Microsoft.Network/virtualNetworks  \
        --resource "$VNET_NAME" \
        --query [].name \
        --output tsv \
        --only-show-errors)"
fi

printf " Done.\n"

if [ -n "$CLUSTERLOCK" ] || [ -n "$VNETLOCK" ]; then
    echo -e ""
    echo -e "Azure lock status:"
    echo -e "   ------------------------------------------------------------------"
    if [ -n "$CLUSTERLOCK" ]; then
        printf "   -  AZ Cluster               : %s               ${red}Locked${normal} by %s\n" "$CLUSTER_NAME" "$CLUSTERLOCK"
    else
        printf "   -  AZ Cluster               : %s               ${grn}unlocked${normal}\n" "$CLUSTER_NAME"
    fi
    if [ -n "$VNETLOCK" ]; then
        printf "   -  AZ VirtualNetworks       : %s          ${red}Locked${normal} by %s\n" "$VNET_NAME" "$VNETLOCK"
    else
    printf "   -  AZ VirtualNetworks       : %s          ${grn}unlocked${normal}\n" "$VNET_NAME"
    fi
    echo -e "   -------------------------------------------------------------------"
    printf "One or more resources are locked prior to teardown. Please resolve and re-run script.\n"; exit 0;
fi


# Read the cluster config that correnspond to selected environment in the zone config.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${CLUSTER_TYPE}.env"

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME"
AZ_ENVIROMENT=($(az aks get-upgrades --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME"))
CP_VERSION="$(jq -r ."controlPlaneProfile"."kubernetesVersion" <<< ${AZ_ENVIROMENT[@]})"
AVAIL_VERSIONS=($(jq -r '[."controlPlaneProfile"."upgrades"[] | ."kubernetesVersion"] | @tsv' <<< ${AZ_ENVIROMENT[@]}))
upgradable=false



for upgrade in "${AVAIL_VERSIONS[@]}"; do
    if [[ $upgrade == $KUBERNETES_VERSION ]]; then
        upgradable=true
    fi
done

if [[ $upgradable == false ]]; then
    echo "The selected version are not available. Use on of the following:"
    echo "${AVAIL_VERSIONS[@]}"
    exit 1
fi

upgrade_cp=false

if [ $(version $CP_VERSION) -lt $(version "$KUBERNETES_VERSION") ]; then
    printf ""${yel}"Upgrade kubernetes in "$CLUSTER_NAME" to "$KUBERNETES_VERSION" requires upgrade of control-plane first.${normal}\n"
    while true; do
        read -r -p "Do you wish to upgrade control-plane to "$KUBERNETES_VERSION"? (Y/n) " yn
        case $yn in
            [Yy]* ) upgrade_cp=true; break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ $upgrade_cp == true ]]; then
    echo "Upgradring Control-Plane in $CLUSTER_NAME."
    az aks upgrade --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" --control-plane-only --kubernetes-version "$KUBERNETES_VERSION"
fi

NODEPOOLS=($(kubectl get nodes -ojson | jq -r '[.items[].metadata.labels.agentpool] | unique | @tsv'))
SUBNET_ID=($(az network vnet subnet list --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --vnet-name "$VNET_NAME" --query [].id --output tsv))

echo -e ""
echo -e "Existing nodepools in "$CLUSTER_NAME""
echo -e ""
echo -e "   >  Nodepool:"
echo -e "   ------------------------------------------------------------------"
for node in "${NODEPOOLS[@]}"; do
echo -e "   -  NODE_NAME                        : $node"
done
echo -e "   ------------------------------------------------------------------"


while :; do
  read -p "Assign a new number for new nodepool between 2 and 9: " newnodepool
  [[ $newnodepool =~ ^[2-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((newnodepool >= 2 && newnodepool <= 9)); then
    break
  else
    echo "number out of range, try again"
  fi
done

while :; do
  read -p "Enter the old nodepool to downscale between 1 and 9: " oldnodepool
  [[ $oldnodepool =~ ^[1-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((oldnodepool >= 1 && oldnodepool <= 9)); then
    break
  else
    echo "number out of range, try again"
  fi
done

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Nodeupgrade will use the following configuration:"
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
echo -e "   -  MIGRATE FROM NODEPOOL            : nodepool$oldnodepool"
echo -e "   -  MIGRATE TO NODEPOOL              : nodepool$newnodepool"
echo -e "   -  KUBERNETES VERSION               : $KUBERNETES_VERSION"
echo -e "   -  SUBNET ID                        : $SUBNET_ID"
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
fi


AKS_BASE_OPTIONS=(
    --cluster-name "$CLUSTER_NAME"
    --name "nodepool$newnodepool"
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"
    --kubernetes-version "$KUBERNETES_VERSION"
    --node-osdisk-size "$NODE_DISK_SIZE"
    --node-vm-size "$NODE_VM_SIZE"
    --max-pods "$POD_PER_NODE"
    --vnet-subnet-id "$SUBNET_ID"
    --mode System
    --enable-cluster-autoscaler
    --node-count "$NODE_COUNT"
    --min-count "$MIN_COUNT"
    --max-count "$MAX_COUNT"
)

echo "Creating new nodepool nodepool$newnodepool"
az aks nodepool add "${AKS_BASE_OPTIONS[@]}"

echo "Modify nodepool$oldnodepool. Disable Autoscaler and mode: User"
az aks nodepool update --cluster-name "$CLUSTER_NAME" --name "nodepool${oldnodepool}" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --disable-cluster-autoscaler --mode User
NODES=($(kubectl get nodes -ojson | jq -r '[.items[].metadata.labels | select(.agentpool=="nodepool'$oldnodepool'") | ."kubernetes.io/hostname"] | @tsv'))
echo "Cordon and drain nodes in nodepool$oldnodepool"
for node in "${NODES[@]}"; do
    kubectl cordon "$node"
    kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=60 "$node"
done
az aks nodepool scale --cluster-name "$CLUSTER_NAME" --name "nodepool${oldnodepool}" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --node-count 0

#######################################################################################
### Lock cluster and network resources
###
if [ "$RADIX_ENVIRONMENT" = "prod" ]; then
    az lock create --lock-type CanNotDelete --name "${CLUSTER_NAME}"-lock --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --resource-type Microsoft.ContainerService/managedClusters --resource "$CLUSTER_NAME"  &>/dev/null
    az lock create --lock-type CanNotDelete --name "${VNET_NAME}"-lock --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --resource-type Microsoft.Network/virtualNetworks --resource "$VNET_NAME"  &>/dev/null
fi


echo ""
echo "Upgrade of \"${CLUSTER_NAME}\" done!"
