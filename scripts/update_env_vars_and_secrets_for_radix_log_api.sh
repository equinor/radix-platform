#!/usr/bin/env bash

# PURPOSE
# Sets zone specific configuration Radix Log API:
#   Secrets:
#     - AZURE_CLIENT_ID
#     - AZURE_CLIENT_SECRET
#   Environment variables:
#     - LOG_API_LOG_ANALYTICS_WORKSPACE_ID

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-1" ./update_env_vars_and_secrets_for_radix_log_api.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-1" ./update_env_vars_and_secrets_for_radix_log_api.sh)
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
    echo "ERROR: Please provide CLUSTER_NAME." >&2
    exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_radix_api.sh

# Optional inputs

if [[ -z "$STAGING" ]]; then
    STAGING=false
fi

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

function updateClientCredentialsSecret() {
    local environment="$1"
    local radix_log_api_client_secret_file="radix-log-api-client-secret.yaml"
    local namespace="radix-log-api-${environment}"

    az keyvault secret download \
        -f radix-log-api-client-secret.yaml \
        -n "$APP_REGISTRATION_LOG_API" \
        --vault-name "$AZ_RESOURCE_KEYVAULT"

    SERVER_SECRET_NAME=$(kubectl get secret -l radix-component="server" -n "$namespace" -o=jsonpath=‘{.items[0].metadata.name}’ | sed 's/‘/ /g;s/’/ /g' | tr -d '[:space:]')
    SERVER_SECRET_ENV_FILE="server_secret.env"

    echo "AZURE_CLIENT_ID=$(jq -r .id $radix_log_api_client_secret_file)" >>"$SERVER_SECRET_ENV_FILE"
    echo "AZURE_CLIENT_SECRET=$(jq -r .password $radix_log_api_client_secret_file)" >>"$SERVER_SECRET_ENV_FILE"

    kubectl patch secret "$SERVER_SECRET_NAME" --namespace "$namespace" \
        --patch "$(kubectl create secret generic "$SERVER_SECRET_NAME" --namespace "$namespace" --save-config --from-env-file="$SERVER_SECRET_ENV_FILE" --dry-run=client -o yaml)"

    rm "$radix_log_api_client_secret_file"
    rm "$SERVER_SECRET_ENV_FILE"

    echo "Secret updated for environment $environment"
}

printf "Getting resource to be used to get access token for requests to Radix API..."
resource=$(echo "${OAUTH2_PROXY_SCOPE}" | awk '{print $4}' | sed 's/\/.*//')
if [[ -z ${resource} ]]; then
    echo "ERROR: Could not get Radix API access token resource." >&2
    exit
fi
printf " Done.\n"

printf "Getting Log Analytics workspace Id for container logs"
workspaceId=$(az monitor log-analytics workspace show --name "${AZ_RESOURCE_LOG_ANALYTICS_WORKSPACE}" --resource-group "${AZ_RESOURCE_GROUP_LOGS}" --query customerId -otsv) || exit

updateComponentEnvVar "${resource}" "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-log-api" "qa" "server" "LOG_API_LOG_ANALYTICS_WORKSPACE_ID" "${workspaceId}" STAGING="$STAGING" || exit
updateComponentEnvVar "${resource}" "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-log-api" "prod" "server" "LOG_API_LOG_ANALYTICS_WORKSPACE_ID" "${workspaceId}" STAGING="$STAGING" || exit

updateClientCredentialsSecret "qa"
updateClientCredentialsSecret "prod"

# Restart Radix Log API deployment
printf "Restarting Radix Log API...\n"
kubectl rollout restart deployment -n radix-log-api-qa server
kubectl rollout restart deployment -n radix-log-api-prod server

echo "Done."
