#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Tear down flux from a cluster


#######################################################################################
### PRECONDITIONS
### 

# - AKS cluster is available
# - User has role cluster-admin
# - Helm RBAC is configured in cluster


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
### 

# Normal usage
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./teardown.sh


#######################################################################################
### START
### 

echo ""
echo "Start tear down of flux... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2;  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nERROR: helm not found in PATH. Exiting..." >&2;  exit 1; }
printf "All is good."
echo ""


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

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Script vars

WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$WORK_DIR"/flux.env



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
echo -e "Tear down of fluxwill use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  FLUX                             : Kill it with fire!"
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
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### MAIN
###

# Step 1: Remove the helm release
printf "\nDelete and purge the helm release..."
helm delete flux --purge 2>&1 >/dev/null
printf "...Done.\n"

# Step 1.1: Remove the helm release
printf "\nDelete and purge the helm operator..."
helm delete helm-operator --purge 2>&1 >/dev/null
printf "...Done.\n"

# Step 1.6: Making sure the v1 webhook is really gone
printf "\nMaking sure the v1 webhook is really gone..."
kubectl delete apiservice v1.helm.fluxcd.io 2>&1 >/dev/null
printf "...Done.\n"

# Step 2: Delete the repo credentials
printf "\nDelete the repo credentials..."
kubectl delete secret "$FLUX_PRIVATE_KEY_NAME" 2>&1 >/dev/null
printf "...Done.\n"

# Step 3: Remove all the custom resource definitions
printf "\nDelete all the custom resource definitions..."
kubectl delete -f "$FLUX_HELM_CRD_PATH" 2>&1 >/dev/null
printf "...Done.\n"


#######################################################################################
### END
###

echo ""
echo "Tear down of flux is done!"
