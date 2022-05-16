#!/usr/bin/env bash

# PURPOSE
# Configures the secrets for radix network policy canary on the cluster given the context.

# Example 1:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./update_secret_for_networkpolicy_canary.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./update_secret_for_networkpolicy_canary.sh)
#

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)

echo ""
echo "Updating secret for the radix network policy canary"

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

# Validate mandatory input

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

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify cluster access
###
printf "Verifying cluster access..."
if [[ $(kubectl cluster-info 2>&1) == *"Unable to connect to the server"* ]]; then
    printf "ERROR: Could not access cluster. Quitting...\n"  >&2
    exit 1
fi
printf " OK\n"

function getApiToken() {
    # Get auth token for Radix API
    printf "Getting auth token for Radix API..."
    API_ACCESS_TOKEN_RESOURCE=$(echo ${OAUTH2_PROXY_SCOPE} | awk '{print $4}' | sed 's/\/.*//')
    if [[ -z ${API_ACCESS_TOKEN_RESOURCE} ]]; then
        echo "ERROR: Could not get Radix API access token resource." >&2
        exit 1
    fi

    API_ACCESS_TOKEN=$(az account get-access-token --resource ${API_ACCESS_TOKEN_RESOURCE} | jq -r '.accessToken')
    if [[ -z ${API_ACCESS_TOKEN} ]]; then
        echo "ERROR: Could not get Radix API access token." >&2
        exit 1
    fi
    printf " Done.\n"
}

function getSecret() {
    SECRET_VALUES=$(az keyvault secret show \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --name radix-cicd-canary-values |
    jq '.value | fromjson')
    NETWORKPOLICY_CANARY_PASSWORD=$(echo $SECRET_VALUES | jq -r '.networkPolicyCanary.password')
    if [[ -z "$NETWORKPOLICY_CANARY_PASSWORD" ]]; then
        echo "ERROR: Could not get networkPolicyCanary.password from radix-cicd-canary-values in ${AZ_RESOURCE_KEYVAULT}." >&2
        exit 1
    fi
}

function getAppEnvironments() {
    APP_ENVIRONMENTS=$(curl \
        --silent \
        -X GET \
        "https://server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}/api/v1/applications/radix-networkpolicy-canary/environments" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${API_ACCESS_TOKEN}" \
        | jq .[].name --raw-output)
    if [[ -z "$APP_ENVIRONMENTS" ]]; then
        echo "ERROR: Could not get the app environments of radix-networkpolicy-canary."  >&2
        exit 1
    fi
    printf " Retrieved app environments $(echo $APP_ENVIRONMENTS | tr '\n' ' ')\n\n"
}

function updateSecret() {
    app_env=$1
    printf "Updating NETWORKPOLICY_CANARY_PASSWORD for environment $app_env \n"
    API_REQUEST=$(curl \
         --silent \
         -X PUT \
         "https://server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}/api/v1/applications/radix-networkpolicy-canary/environments/${app_env}/components/web/secrets/NETWORKPOLICY_CANARY_PASSWORD" \
         -H "accept: application/json" \
         -H "Authorization: bearer ${API_ACCESS_TOKEN}" \
         -H "Content-Type: application/json" \
         -d "{ \"secretValue\": \"${NETWORKPOLICY_CANARY_PASSWORD}\"}")
    if [[ "${API_REQUEST}" != "\"Success\"" ]]; then
        echo -e "\nERROR: API request failed."  >&2
        exit 1
    fi
    printf "Secret updated\n"
}

### MAIN
getApiToken
getAppEnvironments
getSecret
for app_env in $APP_ENVIRONMENTS
do
  updateSecret $app_env
done
