#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix-cost-allocation in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV                : Path to *.env file
# - CLUSTER_NAME                  : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT                   : Is human interaction required to run script? true/false. Default is true.
# - REGENERATE_COLLECTOR_PASSWORD : Should existing password for radix-cost-allocation be regenerated and stored in KV? true/false. default is false
# - REGENERATE_API_PASSWORD       : Should existing password for radix-cost-allocation-api be regenerated and stored in KV? true/false. default is false

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of radix-cost-allocation and radix-cost-allocation-api... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
hash sqlcmd 2>/dev/null || {
    echo -e "\nERROR: sqlcmd not found in PATH. Exiting... " >&2
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Set default values for optional input
###

USER_PROMPT=${USER_PROMPT:=true}

REGENERATE_COLLECTOR_PASSWORD=${REGENERATE_COLLECTOR_PASSWORD:-false}

REGENERATE_API_PASSWORD=${REGENERATE_API_PASSWORD:-false}

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

case $REGENERATE_COLLECTOR_PASSWORD in
    true|false) ;;
    *)
        echo 'REGENERATE_COLLECTOR_PASSWORD must be true or false' >&2
        exit 1
        ;;
esac

case $REGENERATE_API_PASSWORD in
    true|false) ;;
    *)
        echo 'REGENERATE_API_PASSWORD must be true or false' >&2
        exit 1
        ;;
esac

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#######################################################################################
### Ask user to verify inputs and az login
###

echo -e ""
echo -e "Bootstrap Radix Cost Allocation and API with the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  REGENERATE_COLLECTOR_PASSWORD    : $REGENERATE_COLLECTOR_PASSWORD"
echo -e "   -  REGENERATE_API_PASSWORD          : $REGENERATE_API_PASSWORD"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

#######################################################################################
### CLUSTER?
###
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME"
kubectl_context="$(kubectl config current-context)"

if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}" ]; then
    echo "kubectl is ready..."
else
    echo "ERROR: Please set your kubectl current-context to be $CLUSTER_NAME" >&2
    exit 1
fi

#######################################################################################
### Verify cluster access
###
verify_cluster_access

(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$CLUSTER_NAME" USER_PROMPT="$USER_PROMPT" REGENERATE_SQL_PASSWORD="$REGENERATE_COLLECTOR_PASSWORD" "${script_dir_path}/bootstrap_collector.sh")
wait # wait for subshell to finish
printf "Done bootstrapping Radix Cost Allocation prerequisites.\n"

(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="$USER_PROMPT" REGENERATE_SQL_PASSWORD="$REGENERATE_API_PASSWORD" "${script_dir_path}/bootstrap_api.sh")
wait # wait for subshell to finish
printf "Done bootstrapping Radix Cost Allocation API prerequisites.\n"