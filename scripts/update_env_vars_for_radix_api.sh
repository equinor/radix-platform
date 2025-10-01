#!/usr/bin/env bash

# PURPOSE
# Sets zone specific configuration for the following Radix API environment variables:
# - REQUIRE_APP_CONFIGURATION_ITEM
# - REQUIRE_APP_AD_GROUPS

# Example 1:
# RADIX_ZONE=dev CLUSTER_NAME="weekly-1" ./update_env_vars_for_radix_api.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE=dev CLUSTER_NAME="weekly-1" ./update_env_vars_for_radix_api.sh)
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

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2" >&2
    exit 1
fi

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
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_DNS=$(jq -r .dnz_zone <<< "$RADIX_RESOURCE_JSON")
RADIX_CLUSTER_EGRESS_IPS=$(jq -r .ip_prefix_egress_ips <<< "$RADIX_RESOURCE_JSON")
RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM=$(yq '.zoneconfig.RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM' <<< "$RADIX_ZONE_YAML")
RADIX_API_REQUIRE_APP_AD_GROUPS=$(yq '.zoneconfig.RADIX_API_REQUIRE_APP_AD_GROUPS' <<< "$RADIX_ZONE_YAML")
CLUSTER_OIDC_ISSUER_URL=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" output -json | jq -r '.oidc_issuer_url.value["'${CLUSTER_NAME}'"]')
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

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "REQUIRE_APP_CONFIGURATION_ITEM" "${RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "REQUIRE_APP_CONFIGURATION_ITEM" "${RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "REQUIRE_APP_AD_GROUPS" "${RADIX_API_REQUIRE_APP_AD_GROUPS}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "REQUIRE_APP_AD_GROUPS" "${RADIX_API_REQUIRE_APP_AD_GROUPS}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "OIDC_KUBERNETES_ISSUER" "${CLUSTER_OIDC_ISSUER_URL}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "OIDC_KUBERNETES_ISSUER" "${CLUSTER_OIDC_ISSUER_URL}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "OIDC_KUBERNETES_AUDIENCE" "${CLUSTER_OIDC_ISSUER_URL}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "OIDC_KUBERNETES_AUDIENCE" "${CLUSTER_OIDC_ISSUER_URL}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "CLUSTER_NAME" "${CLUSTER_NAME}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "CLUSTER_NAME" "${CLUSTER_NAME}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "CLUSTER_EGRESS_IPS" "${RADIX_CLUSTER_EGRESS_IPS}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "CLUSTER_EGRESS_IPS" "${RADIX_CLUSTER_EGRESS_IPS}" STAGING="$STAGING" || exit

updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "CLUSTER_OIDC_ISSUERS" "${CLUSTER_OIDC_ISSUER_URL}" STAGING="$STAGING" || exit
updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "CLUSTER_OIDC_ISSUERS" "${CLUSTER_OIDC_ISSUER_URL}" STAGING="$STAGING" || exit

# Restart Radix API deployment
printf "Restarting Radix API...\n"
kubectl rollout restart deployment -n radix-api-qa server
kubectl rollout restart deployment -n radix-api-prod server

echo "Done."
