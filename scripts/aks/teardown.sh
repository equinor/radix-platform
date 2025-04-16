#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Tear down of a aks cluster and any related infrastructure (vnet and similar) or configuration that was created to specifically support that cluster.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2
# - CLUSTER_NAME        :

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - CREDENTIALS_FILE    : Path to credentials in the form of shell vars. See "Set credentials" for required key/value pairs.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE=dev CLUSTER_NAME=weekly-49 ./teardown.sh > >(tee -a /tmp/stdout.log) 2> >(tee -a /tmp/stderr.log >&2)
#
# or without log:
# RADIX_ZONE=dev CLUSTER_NAME=weekly-49 ./teardown.sh

#######################################################################################
### START
###

echo ""
echo "Start teardown of aks instance... "

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI."${normal}"\n"
    exit 1
fi

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash kubelogin 2>/dev/null || {
    echo -e "\nERROR: kubelogin not found in PATH. Exiting... " >&2
    exit 1
}

hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
    exit 1
}

printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2" >&2
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Source util scripts
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_clusterlist.sh

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
### Environment
###
printf "\n%s► Read YAML configfile $RADIX_ZONE"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "\n%s► Read terraform variables and configuration"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
RADIX_ENVIRONMENT=$(yq '.radix_environment' <<< "$RADIX_ZONE_YAML")
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "$RADIX_ZONE_YAML")
echo ""

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Check if cluster or network resources are locked and not running
###
CLUSTER_EXIST=$(az aks show --resource-group ${AZ_RESOURCE_GROUP_CLUSTERS} --name ${CLUSTER_NAME} --query "name" -o tsv 2>/dev/null)
if [ -n "$CLUSTER_EXIST" ]; then
    POWERSTATE=$(az aks show --resource-group ${AZ_RESOURCE_GROUP_CLUSTERS} --name ${CLUSTER_NAME} --query "powerState.code" --output tsv)
    if [[ $POWERSTATE != "Stopped" ]]; then
        printf ""${yel}"Please stop cluster ${CLUSTER_NAME} before teardown."${normal}"\n"
        exit 0
    fi
fi

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
        --resource-type Microsoft.Network/virtualNetworks \
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
    printf "One or more resources are locked prior to teardown. Please resolve and re-run script.\n"
    exit 0
fi

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Teardown will use the following configuration:"
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
if [[ ${IP_EXISTS} ]]; then
    echo -e "   -  TEST_CLUSTER_PUBLIC_IP_ADDRESS   : $TEST_CLUSTER_PUBLIC_IP_ADDRESS"
fi
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
fi

# Delete the cluster
echo ""
echo "Deleting cluster... "
az aks delete \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --name "$CLUSTER_NAME" \
    --subscription "$AZ_SUBSCRIPTION_ID" \
    --yes \
    --output none \
    --only-show-errors
echo "Done."

terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" init
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply -target module.aks[\"${CLUSTER_NAME}\"].azurerm_kubernetes_cluster_node_pool.this
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply -target module.aks[\"${CLUSTER_NAME}\"].azurerm_network_watcher_flow_log.this #--auto-approve
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply -target module.aks[\"${CLUSTER_NAME}\"].azurerm_kubernetes_cluster.this #--auto-approve
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" init
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" apply

#######################################################################################
### END
###

echo ""
echo "Teardown done!"
