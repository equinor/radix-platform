#!/usr/bin/env bash

# PURPOSE
# Sets zone specific configuration for the following Radix API environment variables:
# - REQUIRE_APP_CONFIGURATION_ITEM
# - REQUIRE_APP_AD_GROUPS

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-51" ./update_env_vars_for_radix_api.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-1" ./update_env_vars_for_radix_api.sh)
#

# INPUTS:
#   CLUSTER_NAME            (Mandatory)
#   RADIX_ZONE_ENV          (Mandatory)

# Optional:
# - STAGING         : Whether or not to use staging certificate. true/false. Default false.

#######################################################################################
### Check for prerequisites binaries
###

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

if [[ -z "$RADIX_ZONE" ]]; then
    echo "ERROR: Please provide RADIX_ZONE" >&2
    exit 1
fi

# if [[ -z "$RADIX_ZONE_ENV" ]]; then
#     echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
#     exit 1
# else
#     if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
#         echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
#         exit 1
#     fi
#     source "$RADIX_ZONE_ENV"
# fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME." >&2
    exit 1
fi

# Source util scripts
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_radix_api.sh

# Optional inputs

if [[ -z "$STAGING" ]]; then
    STAGING=false
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

AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_DNS=$(jq -r .dnz_zone <<< "$RADIX_RESOURCE_JSON")
RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM=$(yq '.zoneconfig.RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM' <<< "$RADIX_ZONE_YAML")


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

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

### MAIN

cluster_oidc_issuer_url=$(az aks show --resource-group=$AZ_RESOURCE_GROUP_CLUSTERS --name=$CLUSTER_NAME  --query=oidcIssuerProfile.issuerUrl --output tsv) || exit


updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "REQUIRE_APP_CONFIGURATION_ITEM" "${RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "REQUIRE_APP_CONFIGURATION_ITEM" "${RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "REQUIRE_APP_AD_GROUPS" "${RADIX_API_REQUIRE_APP_AD_GROUPS}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "REQUIRE_APP_AD_GROUPS" "${RADIX_API_REQUIRE_APP_AD_GROUPS}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "OIDC_KUBERNETES_ISSUER" "${cluster_oidc_issuer_url}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "OIDC_KUBERNETES_ISSUER" "${cluster_oidc_issuer_url}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "OIDC_KUBERNETES_AUDIENCE" "${cluster_oidc_issuer_url}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "OIDC_KUBERNETES_AUDIENCE" "${cluster_oidc_issuer_url}" STAGING="$STAGING" || exit


# Restart Radix API deployment
printf "Restarting Radix API...\n"
kubectl rollout restart deployment -n radix-api-qa server
kubectl rollout restart deployment -n radix-api-prod server

echo "Done."
