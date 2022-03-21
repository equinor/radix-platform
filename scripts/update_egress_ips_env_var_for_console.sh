#!/usr/bin/env bash

# PURPOSE
# Adds all Private IP Prefix IPs assigned to the Radix Zone to a secret in the web component of Radix Web Console.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" RADIX_WEB_CONSOLE_ENV="qa" CLUSTER_NAME="weekly-1" ./update_egress_ips_env_var_for_console.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" RADIX_WEB_CONSOLE_ENV="qa" CLUSTER_NAME="weekly-1" ./update_egress_ips_env_var_for_console.sh)
#

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)
#   WEB_COMPONENT           (Mandatory)
#   RADIX_WEB_CONSOLE_ENV   (Mandatory)

EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME="CLUSTER_EGRESS_IPS"
EGRESS_IPPRE_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/common/providers/Microsoft.Network/publicIPPrefixes/$AZ_IPPRE_OUTBOUND_NAME"

INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME="CLUSTER_INGRESS_IPS"
INGRESS_IPPRE_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/common/providers/Microsoft.Network/publicIPPrefixes/$AZ_IPPRE_INBOUND_NAME"

echo "Updating \"$EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME\" and \"$INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME\" environment variables for Radix Web Console"

# Validate mandatory input

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$WEB_COMPONENT" ]]; then
    echo "Please provide WEB_COMPONENT."
    exit 1
fi

if [[ -z "$RADIX_WEB_CONSOLE_ENV" ]]; then
    echo "Please provide RADIX_WEB_CONSOLE_ENV."
    exit 1
fi

if [[ -z "$OAUTH2_PROXY_SCOPE" ]]; then
    echo "Please provide OAUTH2_PROXY_SCOPE."
    exit 1
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
if [[ $(kubectl cluster-info --request-timeout "5s" 2>&1) == *"Unable to connect to the server"* ]]; then
    printf "ERROR: Could not access cluster. Quitting...\n"
    exit 1
fi
printf " OK\n"

function updateIpsEnvVars() {

    env_var_configmap_name=$1
    ippre_id=$2

    # Get auth token for Radix API
    printf "Getting auth token for Radix API..."
    API_ACCESS_TOKEN_RESOURCE=$(echo $OAUTH2_PROXY_SCOPE | awk '{print $4}' | sed 's/\/.*//')
    if [[ -z $API_ACCESS_TOKEN_RESOURCE ]]; then
        echo "ERROR: Could not get Radix API access token resource."
        return
    fi

    API_ACCESS_TOKEN=$(az account get-access-token --resource $API_ACCESS_TOKEN_RESOURCE | jq -r '.accessToken')
    if [[ -z $API_ACCESS_TOKEN ]]; then
        echo "ERROR: Could not get Radix API access token."
        return
    fi
    printf " Done.\n"

    # Get list of IPs for all Public IP Prefixes assigned to Cluster Type
    printf "Getting list of IPs from all Public IP Prefixes assigned to $CLUSTER_TYPE clusters..."
    IP_PREFIXES="$(az network public-ip list --query "[?publicIpPrefix.id=='$ippre_id'].ipAddress" --output json)"

    if [[ "$IP_PREFIXES" == "[]" ]]; then
        echo -e "\nERROR: Found no IPs assigned to the cluster."
        return
    fi

    # Loop through list of IPs and create a comma separated string. 
    for ippre in $(echo $IP_PREFIXES | jq -c '.[]')
    do
        if [[ -z $IP_LIST ]]; then
            IP_LIST=$(echo $ippre | jq -r '.')
        else
            IP_LIST="$IP_LIST,$(echo $ippre | jq -r '.')"
        fi
    done
    printf " Done.\n"

    printf "Sending PATCH request to Radix API..."
    API_REQUEST=$(curl -s -X PATCH "https://server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}/api/v1/applications/radix-web-console/environments/${RADIX_WEB_CONSOLE_ENV}/components/${WEB_COMPONENT}/envvars" \
        -H "accept: application/json" \
        -H "Authorization: bearer ${API_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "[ { \"name\": \"${env_var_configmap_name}\", \"value\": \"${IP_LIST}\" }]")

    if [[ "$API_REQUEST" != "\"Success\"" ]]; then
        echo -e "\nERROR: API request failed."
        return
    fi
    printf " Done.\n"

    echo "Web component env variable updated with Public IP Prefix IPs."
}


### MAIN
updateIpsEnvVars "$EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME" "$EGRESS_IPPRE_ID"

updateIpsEnvVars "$INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME" "$INGRESS_IPPRE_ID"

# Restart deployment for web component
printf "Restarting web deployment..."
kubectl rollout restart deployment -n radix-web-console-$RADIX_WEB_CONSOLE_ENV $WEB_COMPONENT

echo "Done."