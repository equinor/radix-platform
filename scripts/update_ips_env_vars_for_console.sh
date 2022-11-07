#!/usr/bin/env bash

# PURPOSE
# Adds all Private IP Prefix IPs assigned to the Radix Zone to the environment variables of the web component of Radix Web Console.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" RADIX_WEB_CONSOLE_ENV="qa" CLUSTER_NAME="weekly-1" ./update_ips_env_vars_for_console.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" RADIX_WEB_CONSOLE_ENV="qa" CLUSTER_NAME="weekly-1" ./update_ips_env_vars_for_console.sh)
#

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)
#   WEB_COMPONENT           (Mandatory)
#   RADIX_WEB_CONSOLE_ENV   (Mandatory)

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
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
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

if [[ -z "$WEB_COMPONENT" ]]; then
    echo "ERROR: Please provide WEB_COMPONENT." >&2
    exit 1
fi

if [[ -z "$RADIX_WEB_CONSOLE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_WEB_CONSOLE_ENV." >&2
    exit 1
fi

if [[ -z "$OAUTH2_PROXY_SCOPE" ]]; then
    echo "ERROR: Please provide OAUTH2_PROXY_SCOPE." >&2
    exit 1
fi

EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME="CLUSTER_EGRESS_IPS"
INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME="CLUSTER_INGRESS_IPS"

echo ""
echo "Updating \"$EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME\" and \"$INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME\" environment variables for Radix Web Console"

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

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

verify_cluster_access

function updateIpsEnvVars() {

    env_var_configmap_name="${1}"
    ippre_name="${2}"

    ippre_id="/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.Network/publicIPPrefixes/${ippre_name}"

    # Get auth token for Radix API
    printf "Getting auth token for Radix API..."
    API_ACCESS_TOKEN_RESOURCE=$(echo "${OAUTH2_PROXY_SCOPE}" | awk '{print $4}' | sed 's/\/.*//')
    if [[ -z ${API_ACCESS_TOKEN_RESOURCE} ]]; then
        echo "ERROR: Could not get Radix API access token resource." >&2
        return
    fi

    API_ACCESS_TOKEN=$(az account get-access-token --resource "${API_ACCESS_TOKEN_RESOURCE}" | jq -r '.accessToken')
    if [[ -z ${API_ACCESS_TOKEN} ]]; then
        echo "ERROR: Could not get Radix API access token." >&2
        return
    fi
    printf " Done.\n"

    # Get list of IPs for Public IPs assigned to Cluster Type
    printf "Getting list of IPs from Public IP Prefix %s..." "${ippre_name}"
    IP_PREFIXES="$(az network public-ip list --query "[?publicIPPrefix.id=='${ippre_id}'].ipAddress" --output json)"

    if [[ "${IP_PREFIXES}" == "[]" ]]; then
        echo -e "\nERROR: Found no IPs assigned to the cluster." >&2
        return
    fi

    # Loop through list of IPs and create a comma separated string.
    for ippre in $(echo "${IP_PREFIXES}" | jq -c '.[]'); do
        if [[ -z $IP_LIST ]]; then
            IP_LIST=$(echo "${ippre}" | jq -r '.')
        else
            IP_LIST="${IP_LIST},$(echo "${ippre}" | jq -r '.')"
        fi
    done
    printf " Done.\n"

    MAX_TRIES=15
    try_nr=0
    printf "Sending PATCH request to Radix API..."
    RADIX_API_FQDN="server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}"
    while true; do
        API_REQUEST=$(curl -s -X PATCH "https://${RADIX_API_FQDN}/api/v1/applications/radix-web-console/environments/${RADIX_WEB_CONSOLE_ENV}/components/${WEB_COMPONENT}/envvars" \
            -H "accept: application/json" \
            -H "Authorization: bearer ${API_ACCESS_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "[ { \"name\": \"${env_var_configmap_name}\", \"value\": \"${IP_LIST}\" }]")

        if [[ "${API_REQUEST}" != "\"Success\"" ]]; then
            try_nr=$(($try_nr + 1))
            if [ "$try_nr" -lt $MAX_TRIES ]; then
                sleep_seconds=$(($try_nr * 4))
                echo -e "\nERROR: Patch request to ${RADIX_API_FQDN} failed. Sleeping ${sleep_seconds} seconds and retrying..." >&2
                sleep $sleep_seconds
                continue
            else
                echo -e "\nERROR: Patch request to ${RADIX_API_FQDN} failed. Out of retries, exiting." >&2
                return 1
            fi
        fi
        printf " Done.\n"
        echo "Web component env variable updated with Public IP Prefix IPs."
        unset IP_LIST
        break
    done
}

### MAIN
updateIpsEnvVars "${EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME}" "${AZ_IPPRE_OUTBOUND_NAME}" || exit 1
updateIpsEnvVars "${INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME}" "${AZ_IPPRE_INBOUND_NAME}" || exit 1

# Restart deployment for web component
printf "Restarting web deployment...\n"
kubectl rollout restart deployment -n radix-web-console-"${RADIX_WEB_CONSOLE_ENV}" "${WEB_COMPONENT}"

echo "Done."
