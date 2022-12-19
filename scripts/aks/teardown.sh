#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Tear down of a aks cluster and any related infrastructure (vnet and similar) or configuration that was created to specifically support that cluster.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        :

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - CREDENTIALS_FILE    : Path to credentials in the form of shell vars. See "Set credentials" for required key/value pairs.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 ./teardown.sh > >(tee -a /tmp/stdout.log) 2> >(tee -a /tmp/stderr.log >&2)
#
# or without log:
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 ./teardown.sh

#######################################################################################
### START
###

echo ""
echo "Start teardown of aks instance... "

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
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash kubelogin 2>/dev/null || {
    echo -e "\nERROR: kubelogin not found in PATH. Exiting... " >&2
    exit 1
}

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
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/aks/${CLUSTER_TYPE}.env

# Source util scripts
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

WHITELIST_IP_IN_ACR_SCRIPT="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/acr/update_acr_whitelist.sh"
if [[ ! -f "$WHITELIST_IP_IN_ACR_SCRIPT" ]]; then
    echo "ERROR: The dependency WHITELIST_IP_IN_ACR_SCRIPT=$WHITELIST_IP_IN_ACR_SCRIPT is invalid, the file does not exist." >&2
    exit 1
fi

# Optional inputs
if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$HUB_PEERING_NAME" ]]; then
    HUB_PEERING_NAME=hub-to-${CLUSTER_NAME}
fi

if [[ -z "$VNET_DNS_LINK" ]]; then
    VNET_DNS_LINK=$CLUSTER_NAME-link
fi

# Define web console variables
RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE == "development" ]]; then
    # Development cluster uses QA web-console
    RADIX_WEB_CONSOLE_ENV="qa"
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"


#TEMP
echo ""
echo "Deleting Dynatrace integration..."
printf "%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../dynatrace/teardown.sh" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="true" CLUSTER_NAME="$CLUSTER_NAME" ../dynatrace/teardown.sh)

echo ""
printf "%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../dynatrace/dashboard/teardown-dashboard.sh" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="true" CLUSTER_NAME="$CLUSTER_NAME" ../dynatrace/dashboard/teardown-dashboard.sh)

#######################################################################################
### Check if cluster or network resources are locked
###

printf "Checking for resource locks..."

CLUSTER=$(az aks list \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --query "[?name=='"${CLUSTER_NAME}"'].name" \
    --output tsv \
    --only-show-errors)

if [[ "${CLUSTER}" ]]; then
    CLUSTERLOCK="$(az lock list \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --resource-type Microsoft.ContainerService/managedClusters \
        --resource "$CLUSTER_NAME" \
        --query [].name \
        --output tsv \
        --only-show-errors)"
fi

VNET=$(az network vnet list \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --query "[?name=='"${VNET_NAME}"'].name" \
    --output tsv \
    --only-show-errors)

if [[ "${VNET}" ]]; then
    VNETLOCK="$(az lock list \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --resource-type Microsoft.Network/virtualNetworks \
        --resource "$VNET_NAME" \
        --query [].name \
        --output tsv \
        --only-show-errors)"
fi

printf " Done.\n"

if [ -n "$CLUSTERLOCK" ] || [ -n "$VNETLOCK" ]; then
    echo -e ""
    echo -e "Azure lock status:"
    echo -e "   ------------------------------------------------------------------"
    if [ -n "$CLUSTERLOCK" ]; then
        printf "   -  AZ Cluster               : %s               ${red}Locked${normal} by %s\n" "$CLUSTER_NAME" "$CLUSTERLOCK"
    else
        printf "   -  AZ Cluster               : %s               ${grn}unlocked${normal}\n" "$CLUSTER_NAME"
    fi
    if [ -n "$VNETLOCK" ]; then
        printf "   -  AZ VirtualNetworks       : %s          ${red}Locked${normal} by %s\n" "$VNET_NAME" "$VNETLOCK"
    else
        printf "   -  AZ VirtualNetworks       : %s          ${grn}unlocked${normal}\n" "$VNET_NAME"
    fi
    echo -e "   -------------------------------------------------------------------"
    printf "One or more resources are locked prior to teardown. Please resolve and re-run script.\n"
    exit 0
fi

#######################################################################################
### Check for test cluster public IPs
###

CLUSTER_PIP_NAME="pip-radix-ingress-${RADIX_ZONE}-${RADIX_ENVIRONMENT}-${CLUSTER_NAME}"
IP_EXISTS=$(az network public-ip list \
    --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --query "[?name=='${CLUSTER_PIP_NAME}'].{id:id, ipAddress:ipAddress}" \
    --only-show-errors)

if [[ ${IP_EXISTS} ]]; then
    TEST_CLUSTER_PUBLIC_IP_ADDRESS=$(echo ${IP_EXISTS} | jq '.[].ipAddress')
    TEST_CLUSTER_PUBLIC_IP_ID=$(echo ${IP_EXISTS} | jq -r '.[].id')
fi

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Teardown will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
if [[ ${IP_EXISTS} ]]; then
    echo -e "   -  TEST_CLUSTER_PUBLIC_IP_ADDRESS   : $TEST_CLUSTER_PUBLIC_IP_ADDRESS"
fi
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
### Delete cluster
###

printf "Verifying that cluster exist and/or the user can access it... "
# We use az aks get-credentials to test if both the cluster exist and if the user has access to it.

get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found, or you do not have access to it." >&2
    if [[ $USER_PROMPT == true ]]; then
        echo ""
        while true; do
            read -r -p "Do you want to continue? (Y/n) " yn
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
    else
        exit 0
    fi
}
printf "Done.\n"

# Determining egress IP of cluster before deletion
migration_strategy=$(az resource show --id /subscriptions/${AZ_SUBSCRIPTION_ID}/resourcegroups/${AZ_RESOURCE_GROUP_CLUSTERS}/providers/Microsoft.ContainerService/managedClusters/${CLUSTER_NAME} --query tags.migrationStrategy -o tsv)
if [[ "${migration_strategy}" == "at" ]]; then
  echo ""
  echo "Cluster ${CLUSTER_NAME} is a test cluster. Determining cluster egress IP in order to remove it after cluster deletion..."
  egress_ip_range=$(get_cluster_outbound_ip ${migration_strategy} ${CLUSTER_NAME} ${AZ_SUBSCRIPTION_ID} ${AZ_IPPRE_OUTBOUND_NAME} ${AZ_RESOURCE_GROUP_COMMON})
  echo ""
fi
echo "Done."

# Delete the cluster
echo ""
echo "Deleting cluster... "
az aks delete \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --name "$CLUSTER_NAME" \
    --subscription "$AZ_SUBSCRIPTION_ID" \
    --yes \
    --output none \
    --only-show-errors
echo "Done."

#######################################################################################
### Delete ACR network rule
###

if [[ "${migration_strategy}" == "at" ]]; then
  echo ""
  echo "Cluster ${CLUSTER_NAME} is a test cluster. Removing egress IP range ${egress_ip_range} from ACR rules..."
  printf "%s► Execute %s%s\n" "${grn}" "$WHITELIST_IP_IN_ACR_SCRIPT" "${normal}"
  (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" IP_MASK=${egress_ip_range} IP_LOCATION=$CLUSTER_NAME ACTION=delete $WHITELIST_IP_IN_ACR_SCRIPT)
  wait # wait for subshell to finish
  echo ""
else
  echo "Cluster ${CLUSTER_NAME} is a non-test cluster. Leaving ACR network rules as they are..."
fi
echo "Done."


#######################################################################################
### Delete Redis Cache
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf "\n%s► Execute Redis Cache for QA %s%s\n" "${grn}" "$WORKDIR_PATH/../redis/delete_redis_cache_for_console.sh" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$CLUSTER_NAME" RADIX_WEB_CONSOLE_ENV="qa" USER_PROMPT="$USER_PROMPT" source "$WORKDIR_PATH/../redis/delete_redis_cache_for_console.sh")
wait # wait for subshell to finish
echo ""
printf "%s► Execute Redis Cache for Prod %s%s\n" "${grn}" "$WORKDIR_PATH/../redis/delete_redis_cache_for_console.sh" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$CLUSTER_NAME" RADIX_WEB_CONSOLE_ENV="prod" USER_PROMPT="$USER_PROMPT" source "$WORKDIR_PATH/../redis/delete_redis_cache_for_console.sh")
wait # wait for subshell to finish

#######################################################################################
### Delete replyUrls
###

echo ""
echo "Delete replyUrls"

# Delete replyUrl for Radix web-console
WEB_CONSOLE_ENV="radix-web-console-$RADIX_WEB_CONSOLE_ENV"
APP_REGISTRATION_WEB_CONSOLE="Omnia Radix Web Console - ${CLUSTER_TYPE^} Clusters" # "Development", "Playground", "Production"
APP_REGISTRATION_ID="$(az ad app list --display-name "${APP_REGISTRATION_WEB_CONSOLE}" --query [].appId --output tsv --only-show-errors)"
APP_REGISTRATION_OBJ_ID="$(az ad app list --display-name "${APP_REGISTRATION_WEB_CONSOLE}" --query [].id --output tsv --only-show-errors)"
HOST_NAME_WEB_CONSOLE="auth-${WEB_CONSOLE_ENV}.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}"
REPLY_URL="https://${HOST_NAME_WEB_CONSOLE}/oauth2/callback"
WEB_REDIRECT_URI="https://${HOST_NAME_WEB_CONSOLE}/applications"

printf "%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../delete_reply_url_for_cluster.sh" "${normal}"
(APP_REGISTRATION_ID="$APP_REGISTRATION_ID" APP_REGISTRATION_OBJ_ID="${APP_REGISTRATION_OBJ_ID}" REPLY_URL="$REPLY_URL" USER_PROMPT="$USER_PROMPT" WEB_REDIRECT_URI="$WEB_REDIRECT_URI" source "$WORKDIR_PATH/../delete_reply_url_for_cluster.sh")
wait # wait for subshell to finish

# Delete replyUrl for grafana
APP_REGISTRATION_ID="$(az ad app list --display-name "${APP_REGISTRATION_GRAFANA}" --query [].appId --output tsv --only-show-errors)"
HOST_NAME_GRAFANA="grafana.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}"
REPLY_URL="https://${HOST_NAME_GRAFANA}/login/generic_oauth"

printf "\n%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../delete_reply_url_for_cluster.sh" "${normal}"
(APP_REGISTRATION_ID="$APP_REGISTRATION_ID" APP_REGISTRATION_OBJ_ID="${APP_REGISTRATION_OBJ_ID}" REPLY_URL="$REPLY_URL" USER_PROMPT="$USER_PROMPT" WEB_REDIRECT_URI="" source "$WORKDIR_PATH/../delete_reply_url_for_cluster.sh")
wait # wait for subshell to finish

#######################################################################################
### Delete related stuff
###

#To be deleted
# echo ""
# echo "Deleting Dynatrace integration..."
# printf "%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../dynatrace/teardown.sh" "${normal}"
# (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="false" CLUSTER_NAME="$CLUSTER_NAME" ../dynatrace/teardown.sh)

# echo ""
# printf "%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../dynatrace/dashboard/teardown-dashboard.sh" "${normal}"
# (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="false" CLUSTER_NAME="$CLUSTER_NAME" ../dynatrace/dashboard/teardown-dashboard.sh)

echo "Cleaning up local kube config... "
kubectl config delete-context "${CLUSTER_NAME}" &>/dev/null
if [[ "$(kubectl config get-contexts -o name)" == *"${CLUSTER_NAME}"* ]]; then
    kubectl config delete-context "${CLUSTER_NAME}" &>/dev/null
fi
kubectl config delete-cluster "${CLUSTER_NAME}" &>/dev/null
echo "Done."

if [[ "${VNET}" ]]; then
    echo "Deleting vnet... "
    az network vnet peering delete \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --name "$VNET_PEERING_NAME" \
        --vnet-name "$VNET_NAME" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --output none \
        --only-show-errors

    az network vnet peering delete \
        --resource-group "$AZ_RESOURCE_GROUP_VNET_HUB" \
        --name "$HUB_PEERING_NAME" \
        --vnet-name "$AZ_VNET_HUB_NAME" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --output none \
        --only-show-errors

    az network vnet delete \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --name "$VNET_NAME" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --output none \
        --only-show-errors
    echo "Done."
fi

echo "Deleting Network Security Group..."
az network nsg delete \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --name "$NSG_NAME" \
    --subscription "$AZ_SUBSCRIPTION_ID"
echo "Done."

if [[ ${TEST_CLUSTER_PUBLIC_IP_ADDRESS} ]]; then
    # IP cannot be deleted while still allocated to loadbalancer.
    printf "Deleting Public IP %s..." "${TEST_CLUSTER_PUBLIC_IP_ADDRESS}"
    az network public-ip delete \
        --ids "${TEST_CLUSTER_PUBLIC_IP_ID}" \
        --output none \
        --only-show-errors
    printf "Done.\n"
fi

echo ""
echo "Delete DNS records"
printf "%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../dns/delete_dns_entries_for_cluster.sh" "${normal}"
(RADIX_ENVIRONMENT="$RADIX_ENVIRONMENT" CLUSTER_TYPE="$CLUSTER_TYPE" RESOURCE_GROUP="$RESOURCE_GROUP" DNS_ZONE="$DNS_ZONE" CLUSTER_NAME="$CLUSTER_NAME" ../dns/delete_dns_entries_for_cluster.sh)
wait # wait for subshell to finish

echo ""
echo "Delete orphaned DNS records"
printf "%s► Execute %s%s\n" "${grn}" "$WORKDIR_PATH/../dns/delete_orphaned_dns_entries.sh" "${normal}"
(RADIX_ENVIRONMENT="$RADIX_ENVIRONMENT" CLUSTER_TYPE="$CLUSTER_TYPE" RESOURCE_GROUP="$RESOURCE_GROUP" DNS_ZONE="$DNS_ZONE" ../dns/delete_orphaned_dns_entries.sh)
wait # wait for subshell to finish

#######################################################################################
### END
###

echo ""
echo "Teardown done!"
