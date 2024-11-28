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

if [ "${CILIUM}" = true ]; then
    hash cilium 2>/dev/null || {
        echo -e "\nERROR: cilium not found in PATH. Exiting... " >&2
        exit 1
    }
fi

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
    exit 1
}

hash helm 2>/dev/null || {
    echo -e "\nERROR: helm not found in PATH. Exiting... " >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash terraform 2>/dev/null || {
    echo -e "\nERROR: terraform not found in PATH. Exiting..." >&2
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

if [[ -z "$MIGRATION_STRATEGY" ]]; then
    echo "ERROR: Please provide MIGRATION_STRATEGY" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
if [[ "${RADIX_ZONE}" == "c2" ]]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${RADIX_ZONE}.env"
else
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${CLUSTER_TYPE}.env"
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_clusterlist.sh
LIB_DNS_SCRIPT="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/dns/lib_dns.sh"
if ! [[ -x "$LIB_DNS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The lib DNS script is not found or it is not executable in path $LIB_DNS_SCRIPT" >&2
else
    source $LIB_DNS_SCRIPT
fi

# Optional inputs

if [[ -z "$CREDENTIALS_FILE" ]]; then
    CREDENTIALS_FILE=""
else
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "ERROR: CREDENTIALS_FILE=\"${CREDENTIALS_FILE}\" is not a valid file path." >&2
        exit 1
    fi
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$HUB_PEERING_NAME" ]]; then
    HUB_PEERING_NAME=hub-to-${CLUSTER_NAME}
fi

if [[ -z "$VNET_DNS_LINK" ]]; then
    VNET_DNS_LINK=$CLUSTER_NAME-link
fi

# Script vars

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"


printf "Initializing Terraform..."
terraform -chdir="../terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/clusters" init
terraform -chdir="../terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/clusters" apply
terraform -chdir="../terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" init
terraform -chdir="../terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" init
#######################################################################################


terraform -chdir="../terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply -target module.aks[\"${CLUSTER_NAME}\"].azurerm_virtual_network.this --auto-approve
terraform -chdir="../terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply

#######################################################################################
### Do some terraform post tasks
###
echo "Do some terraform post tasks"
terraform -chdir="../terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" apply
printf "Done."
#######################################################################################
### END

#######################################################################################
### Update local kube config
###

printf "Updating local kube config with access to cluster \"%s\"... " "$CLUSTER_NAME"
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" >/dev/null

[[ "$(kubectl config current-context)" != "$CLUSTER_NAME" ]] && exit 1

printf "Done.\n"


echo ""
echo "Bootstrap of \"${CLUSTER_NAME}\" done!"
