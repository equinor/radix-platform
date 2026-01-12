#!/usr/bin/env bash

# PURPOSE
# Configures the secrets for radix network policy canary on the cluster given the context.

# Example 1:
# RADIX_ZONE=dev CLUSTER_NAME="weekly-01" ./update_secret_for_networkpolicy_canary.sh
#
# Example 2: Reset the Appreg password and update keyvault
# # RADIX_ZONE=dev  CLUSTER_NAME="weekly-01" ./update_secret_for_networkpolicy_canary.sh --reset
#
# Example 3: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE=dev CLUSTER_NAME="weekly-01" ./update_secret_for_networkpolicy_canary.sh)
#

# Optional:
# - STAGING         : Whether or not to use staging certificate. true/false. Default false.

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

echo ""
echo "Updating secret for the radix network policy canary"

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

# Validate mandatory input

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

for arg in "$@"; do
  if [ "$arg" == "--reset" ]; then
    RESET=true
    # Add your reset logic here
  fi
done

# Source util scripts
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [[ $STAGING == true ]]; then
    curl_command="curl --cacert /usr/local/share/ca-certificates/letsencrypt-stg-root-x1.pem"
else
    STAGING=false
    curl_command="curl"
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
OAUTH2_PROXY_SCOPE="openid profile offline_access 6dae42f8-4368-4678-94ff-3960e28e3630/user.read email"
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_DNS=$(jq -r .dnz_zone <<< "$RADIX_RESOURCE_JSON")
APP_REGISTRATION_NETWORKPOLICY_CANARY=$(yq '.zoneconfig.APP_REGISTRATION_NETWORKPOLICY_CANARY' <<< "$RADIX_ZONE_YAML")
echo ""
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
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME"
verify_cluster_access

function getApiTokenResource() {
    # Get auth token for Radix API
    printf "Getting auth token for Radix API...\n"
    API_ACCESS_TOKEN_RESOURCE=$(echo ${OAUTH2_PROXY_SCOPE} | awk '{print $4}' | sed 's/\/.*//')
    if [[ -z ${API_ACCESS_TOKEN_RESOURCE} ]]; then
        echo "ERROR: Could not get Radix API access token resource." >&2
        return 1
    fi
}

function getApiToken() {
    API_ACCESS_TOKEN=$(az account get-access-token --resource ${API_ACCESS_TOKEN_RESOURCE} | jq -r '.accessToken')
    if [[ -z ${API_ACCESS_TOKEN} ]]; then
        echo "ERROR: Could not get Radix API access token." >&2
        return 1
    fi
    printf "Done.\n"
}

function getSecret() {
    SECRET_VALUES=$(az keyvault secret show \
        --vault-name "$AZ_RESOURCE_KEYVAULT" \
        --name radix-cicd-canary-values |
        jq '.value | fromjson')
    NETWORKPOLICY_CANARY_PASSWORD=$(echo $SECRET_VALUES | jq -r '.networkPolicyCanary.password')
    if [[ -z "$NETWORKPOLICY_CANARY_PASSWORD" ]]; then
        echo "ERROR: Could not get networkPolicyCanary.password from radix-cicd-canary-values in ${AZ_RESOURCE_KEYVAULT}." >&2
        return 1
    fi
}

function getAppEnvironments() {
    printf "Waiting for enviroment %shttps://server-radix-api-prod.%s/api/v1/applications/radix-networkpolicy-canary/environments %s" "${yel}" "${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "${normal}"
    while [[ -z "$APP_ENVIRONMENTS" ]]; do
        printf "."
        sleep 5
        APP_ENVIRONMENTS=$($curl_command \
            --silent \
            -X GET \
            "https://server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}/api/v1/applications/radix-networkpolicy-canary/environments" \
            -H 'accept: application/json' \
            -H 'Content-Type: application/json' \
            -H "Authorization: Bearer ${API_ACCESS_TOKEN}" |
            jq .[].name --raw-output)
    done
    printf "\nRetrieved app environments $(echo $APP_ENVIRONMENTS | tr '\n' ' ')\n\n"
}

function updateSecret() {
    app_env=$1
    secret_name=$2
    secret_value=$3
    radix_component=$4
    printf "Updating ${secret_name} for environment ${app_env} in ${radix_component} component..."
    API_REQUEST=$($curl_command \
        --silent \
        -X PUT \
        "https://server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}/api/v1/applications/radix-networkpolicy-canary/environments/${app_env}/components/${radix_component}/secrets/${secret_name}" \
        -H "accept: application/json" \
        -H "Authorization: bearer ${API_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{ \"secretValue\": \"${secret_value}\"}")
    if [[ "${API_REQUEST}" != "\"Success\"" ]]; then
        echo -e "\nERROR: API request failed." >&2
        return 1
    fi
    # echo "API_REQUEST=$($curl_command \
    #     --silent \
    #     -X PUT \
    #     "https://server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}/api/v1/applications/radix-networkpolicy-canary/environments/${app_env}/components/${radix_component}/secrets/${secret_name}" \
    #     -H "accept: application/json" \
    #     -H "Authorization: bearer ${API_ACCESS_TOKEN}" \
    #     -H "Content-Type: application/json" \
    #     -d "{ \"secretValue\": \"${secret_value}\"}")"
    printf " Secret updated\n"
}

function environmentIsOauthEnvironment() {
    env=$1
    GET_ENV=$($curl_command \
        --silent \
        --request GET \
        "https://server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}/api/v1/applications/radix-networkpolicy-canary/environments/${env}" \
        --header 'accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer ${API_ACCESS_TOKEN}")

    if [[ $(echo ${GET_ENV} | jq -r .error) != null ]]; then
        echo "${GET_ENV}" | jq . >&2
        echo "ERROR: Could not get the app secrets of the ${env} environment in radix-networkpolicy-canary." >&2
        return 1
    elif [[ $(echo ${GET_ENV} | jq --raw-output '.secrets[] | select(.name=="web-oauth2proxy-clientsecret")') ]]; then
        return 0
    else
        return 1
    fi
}

function getOauthAppEnvironments() {
    OAUTH_APP_ENVIRONMENTS=""
    for app_env in $APP_ENVIRONMENTS; do
        if environmentIsOauthEnvironment $app_env; then
            printf "$app_env is OAuth2-enabled app environment. Updating \n"
            OAUTH_APP_ENVIRONMENTS="${OAUTH_APP_ENVIRONMENTS} $app_env"
        else
            printf "$app_env is not OAuth2-enabled app environment\n"
        fi
    done

    if [[ "$OAUTH_APP_ENVIRONMENTS" == "" ]]; then
        printf "ERROR: No OAuth2-enabled app environments.\n" >&2
        return 1
    fi
}

function updateNetworkPolicyCanaryHttpPassword() {
    printf "Updating NETWORKPOLICY_CANARY_PASSWORD...\n"
    getApiTokenResource || return 1
    getApiToken || return 1
    getAppEnvironments && getSecret
    for app_env in $APP_ENVIRONMENTS; do
        updateSecret $app_env NETWORKPOLICY_CANARY_PASSWORD ${NETWORKPOLICY_CANARY_PASSWORD} web || return 1
    done
}

function updateNetworkPolicyOauthAppRegistrationPasswordAndRedisSecret() {
    printf "Resetting ${APP_REGISTRATION_NETWORKPOLICY_CANARY} credentials and updating radixapp secrets...\n"
    getApiTokenResource || return 1
    getApiToken || return 1
    if [[ $RESET == true ]]; then
        getAppEnvironments && getOauthAppEnvironments && resetAppRegistrationPassword
        EXPIRY_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" --date="$KV_EXPIRATION_TIME")
        az keyvault secret set \
            --vault-name "${AZ_RESOURCE_KEYVAULT}" \
            --name "ar-radix-networkpolicy-canary" \
            --value "${UPDATED_APP_REGISTRATION_PASSWORD}" \
            --expires "${EXPIRY_DATE}" --output none || exit
    else
        local UPDATED_APP_REGISTRATION_PASSWORD=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name ar-radix-networkpolicy-canary | jq -r '.value')
        getAppEnvironments && getOauthAppEnvironments
    fi
    for app_env in $OAUTH_APP_ENVIRONMENTS; do
        updateSecret $app_env web-oauth2proxy-clientsecret ${UPDATED_APP_REGISTRATION_PASSWORD} web || return 1
        redis_password=$(openssl rand -base64 32 | tr -- '+/' '-_')
        updateSecret $app_env web-oauth2proxy-redispassword $redis_password web || return 1
        updateSecret $app_env REDIS_PASSWORD $redis_password redis || return 1
    done
}

function resetAppRegistrationPassword() {
    # Generate new secret for App Registration.
    printf "Re-generate client secret for App Registration \"$APP_REGISTRATION_NETWORKPOLICY_CANARY\"...\n"
    APP_REGISTRATION_CLIENT_ID=$(az ad app list --filter "displayname eq '${APP_REGISTRATION_NETWORKPOLICY_CANARY}'" | jq -r '.[].appId')
    # For some reason, description can not be too long.
    UPDATED_APP_REGISTRATION_PASSWORD=$(az ad app credential reset \
        --id "$APP_REGISTRATION_CLIENT_ID" \
        --display-name "${RADIX_ZONE}" \
        --append \
        --query password \
        --output tsv \
        --only-show-errors) || {
        echo -e "\nERROR: Could not re-generate client secret for App Registration \"$APP_REGISTRATION_NETWORKPOLICY_CANARY\"." >&2
        return 1
    }
    printf " Done.\n"
}

function restartAllEnvironments() {
    printf "Restart networkpolicy-canary app environments..."
    getApiTokenResource || return 1
    getApiToken || return 1
    getAppEnvironments && getSecret
    for app_env in $APP_ENVIRONMENTS; do
        kubectl rollout restart deployment -n radix-networkpolicy-canary-${app_env} web
    done
}

### MAIN
updateNetworkPolicyCanaryHttpPassword || exit 1
updateNetworkPolicyOauthAppRegistrationPasswordAndRedisSecret || exit 1
restartAllEnvironments || exit 1
