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
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_radix_api.sh

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
    local env_var_configmap_name="${1}"
    local ippre_name="${2}"

    local ip_list
    local ippre_id="/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.Network/publicIPPrefixes/${ippre_name}"

    # Get resource for access token
    printf "Getting resource for access token..."
    local resource=$(echo "${OAUTH2_PROXY_SCOPE}" | awk '{print $4}' | sed 's/\/.*//')
    if [[ -z ${resource} ]]; then
        echo "ERROR: Could not get access token resource." >&2
        return
    fi

    # Get list of IPs for Public IPs assigned to Cluster Type
    printf "Getting list of IPs from Public IP Prefix %s..." "${ippre_name}"
    local ip_prefixes="$(az network public-ip list --query "[?publicIPPrefix.id=='${ippre_id}'].ipAddress" --output json)"

    if [[ "${ip_prefixes}" == "[]" ]]; then
        echo -e "\nERROR: Found no IPs assigned to the cluster." >&2
        return
    fi

    # Loop through list of IPs and create a comma separated string.
    for ippre in $(echo "${ip_prefixes}" | jq -c '.[]'); do
        if [[ -z $ip_list ]]; then
            ip_list=$(echo "${ippre}" | jq -r '.')
        else
            ip_list="${ip_list},$(echo "${ippre}" | jq -r '.')"
        fi
    done
    printf " Done.\n"
    
    updateComponentEnvVar "${resource}" "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-web-console" "${RADIX_WEB_CONSOLE_ENV}" "${WEB_COMPONENT}" "${env_var_configmap_name}" "${IP_LIST}"

    echo "Web component env variable updated with Public IP Prefix IPs."
}

### MAIN
updateIpsEnvVars "${EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME}" "${AZ_IPPRE_OUTBOUND_NAME}" || exit 1
updateIpsEnvVars "${INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME}" "${AZ_IPPRE_INBOUND_NAME}" || exit 1

# Restart deployment for web component
printf "Restarting web deployment...\n"
kubectl rollout restart deployment -n radix-web-console-"${RADIX_WEB_CONSOLE_ENV}" "${WEB_COMPONENT}"

echo "Done."
