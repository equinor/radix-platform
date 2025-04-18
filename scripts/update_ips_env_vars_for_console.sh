#!/usr/bin/env bash

# PURPOSE
# Adds all Private IP Prefix IPs assigned to the Radix Zone to the environment variables of the web component of Radix Web Console.

# Example 1:
# RADIX_ZONE=dev RADIX_WEB_CONSOLE_ENV="qa" CLUSTER_NAME="weekly-1" ./update_ips_env_vars_for_console.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE=dev RADIX_WEB_CONSOLE_ENV="qa" CLUSTER_NAME="weekly-1" ./update_ips_env_vars_for_console.sh)
#

# INPUTS:
#   RADIX_ZONE              (Mandatory)
#   RADIX_WEB_CONSOLE_ENV   (Mandatory)

# Optional:
# - STAGING         : Whether or not to use staging certificate. true/false. Default false.

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

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2" >&2
    exit 1
fi

if [[ -z "$RADIX_WEB_CONSOLE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_WEB_CONSOLE_ENV." >&2
    exit 1
fi

# if [[ -z "$OAUTH2_PROXY_SCOPE" ]]; then
#     echo "ERROR: Please provide OAUTH2_PROXY_SCOPE." >&2
#     exit 1
# fi

EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME="CLUSTER_EGRESS_IPS"
INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME="CLUSTER_INGRESS_IPS"

echo ""
echo "Updating \"$EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME\" and \"$INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME\" environment variables for Radix Web Console"

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
echo ""
printf "%s► Read YAML configfile $RADIX_ZONE\n"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "%s► Read terraform variables and configuration\n"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_COMMON=$(jq -r .common_rg <<< "$RADIX_RESOURCE_JSON")
OAUTH2_PROXY_SCOPE="openid profile offline_access 6dae42f8-4368-4678-94ff-3960e28e3630/user.read email"
RADIX_ZONE=$(yq '.environment' <<< "$RADIX_ZONE_YAML")
AZ_IPPRE_OUTBOUND_NAME=$(jq -r .egress_prefix <<< "$RADIX_RESOURCE_JSON")
AZ_IPPRE_INBOUND_NAME=$(jq -r .ingress_prefix <<< "$RADIX_RESOURCE_JSON")


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

# verify_cluster_access

function updateIpsEnvVars() {
    local env_var_configmap_name="${1}"
    local ippre_name="${2}"
    local ip_list
    local ippre_id="/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.Network/publicIPPrefixes/${ippre_name}"
    if [[ $RADIX_ZONE == "c2" ]]; then
        local ippre_id="/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_IPPRE}/providers/Microsoft.Network/publicIPPrefixes/${ippre_name}"
    fi

    # Get list of IPs for Public IPs assigned to Cluster Type
    printf "Getting list of IPs from Public IP Prefix %s..." "${ippre_name}"
    local ip_prefixes="$(az network public-ip list --query "[?publicIPPrefix.id=='${ippre_id}'].ipAddress" --output json)"

    if [[ "${ip_prefixes}" == "[]" ]]; then
        echo -e "\nERROR: Found no IPs assigned to the cluster." >&2
        return
    fi
    if [[ $RADIX_ZONE == "prod" ]]; then
        if [[ $ippre_name = "ippre-radix-aks-production-northeurope-001" ]]; then
            ip_list1=$(az network public-ip prefix show --name ${ippre_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} | jq -r .ipPrefix)
            ip_list2=$(az network public-ip prefix show --name "ippre-radix-aks-platform-northeurope-001" --resource-group "common-platform" | jq -r .ipPrefix)
            ip_list="${ip_list1},${ip_list2}"
        else
            ip_list1=$(az network public-ip prefix show --name ${ippre_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} | jq -r .ipPrefix)
            ip_list2=$(az network public-ip prefix show --name "ippre-ingress-radix-aks-platform-northeurope-001" --resource-group "common-platform" | jq -r .ipPrefix)
            ip_list="${ip_list1},${ip_list2}"
        fi
    elif [[ $RADIX_ZONE == "playground" ]]; then
        if [[ $ippre_name = "ippre-radix-aks-playground-northeurope-001" ]]; then
            ip_list1=$(az network public-ip prefix show --name ${ippre_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} | jq -r .ipPrefix)
            ip_list2=$(az network public-ip prefix show --name "ippre-radix-aks-playground-northeurope-002" --resource-group "clusters-playground" | jq -r .ipPrefix)
            ip_list="${ip_list1},${ip_list2}"
        else
            ip_list=$(az network public-ip prefix show --name ${ippre_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} | jq -r .ipPrefix)
        fi
    elif [[ $RADIX_ZONE == "c2" ]]; then
        if [[ $ippre_name = "ippre-egress-radix-aks-c2-prod-001" ]]; then
            ip_list1=$(az network public-ip prefix show --name ${ippre_name} --resource-group "common-westeurope" | jq -r .ipPrefix)
            ip_list2=$(az network public-ip prefix show --name "ippre-radix-aks-c2-westeurope-001" --resource-group "clusters-c2" | jq -r .ipPrefix)
            ip_list="${ip_list1},${ip_list2}"
        else
            ip_list=$(az network public-ip prefix show --name ${ippre_name} --resource-group "common-westeurope" | jq -r .ipPrefix)
        fi
    else
        ip_list=$(az network public-ip prefix show --name ${ippre_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} | jq -r .ipPrefix)
    fi
    printf "Done.\n"
    updateComponentEnvVar "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-web-console" "${RADIX_WEB_CONSOLE_ENV}" "web" "${env_var_configmap_name}" "${ip_list}"
    echo "Web component env variable updated with Public IP Prefix IPs."
}

### MAIN
updateIpsEnvVars "${EGRESS_IPS_ENV_VAR_CONFIGMAP_NAME}" "${AZ_IPPRE_OUTBOUND_NAME}" STAGING="$STAGING" || exit 1
updateIpsEnvVars "${INGRESS_IPS_ENV_VAR_CONFIGMAP_NAME}" "${AZ_IPPRE_INBOUND_NAME}" STAGING="$STAGING" || exit 1

# Restart deployment for web component
printf "Restarting web deployment...\n"
kubectl rollout restart deployment -n radix-web-console-"${RADIX_WEB_CONSOLE_ENV}" "web"

echo "Done."
