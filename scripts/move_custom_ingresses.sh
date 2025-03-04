#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Move custom ingresses from one cluster to another

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - DEST_CLUSTER        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# Option #1 - migrate ingresses from source to destination cluster
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env DEST_CLUSTER="weekly-51" ./move_custom_ingresses.sh

# Option #2 - configure ingresses from destination cluster only. Useful when creating cluster form scratch
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env DEST_CLUSTER="weekly-3" ./move_custom_ingresses.sh

#######################################################################################
### START
###
echo ""
echo "Start moving custom ingresses..."

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for necessary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}
hash helm 2>/dev/null || {
    echo -e "\nERROR: helm not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
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

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh


LIB_DNS_SCRIPT="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/dns/lib_dns.sh"
if ! [[ -x "$LIB_DNS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The lib DNS script is not found or it is not executable in path $LIB_DNS_SCRIPT" >&2
else
    source $LIB_DNS_SCRIPT
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
echo -e "Move custom ingresses will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  DEST_CLUSTER                     : $DEST_CLUSTER"
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

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$DEST_CLUSTER\" not found." >&2
    exit 1
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Move custom ingresses
###


echo ""
printf "Point to destination cluster... "
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER"
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER" ]] && exit 1


#######################################################################################
### Configure DNS Record to point to new cluster
###

echo ""
printf "Updating DNS zone for %s... " "${AZ_RESOURCE_GROUP_COMMON}"

# Get cluster IP
cluster_ip=$(kubectl get service --namespace "ingress-nginx" "ingress-nginx-controller" -ojson | jq '.status.loadBalancer.ingress[0].ip' --raw-output)

set -f
a_records=('@' '*' '*.app')
# Create A records in the dns zone
# creating the "@"-record, i.e. e.g. dev.radix.equinor.com.
# creating wildcard record to match all FQDNs in active-cluster ingresses
# creating wildcard record to match all FQDNs in "app alias" ingresses
for record in ${a_records[@]}; do

    printf "%s... " $record
    create-a-record "${record}" "$cluster_ip" "$AZ_RESOURCE_GROUP_IPPRE" "$AZ_RESOURCE_DNS" "60" || {
        echo "ERROR: failed to create A record ${record}.${AZ_RESOURCE_DNS}" >&2
    }
done
set +f
printf "Done. \n"

#######################################################################################

if [[ -z $CI ]]; then
    echo ""
    echo "###########################################################"
    echo ""
    echo "NOTE: You need to manually activate the cluster"
    echo ""
    echo "You do this in the https://github.com/equinor/radix-flux repo"
    echo ""
    echo "###########################################################"
    echo ""
fi
