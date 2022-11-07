#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap ingress-nginx in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "playground-2", "weekly-93"

# Optional:
# - MIGRATION_STRATEGY  : Is this an active or a testing cluster? Ex: "aa", "at". Default is "at".
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" MIGRATION_STRATEGY="aa" ./bootstrap.sh

# Testing cluster
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### START
###

# Script vars
WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import networking variables for AKS
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../aks/network.env"

echo ""
echo "Start bootstrap of ingress-nginx... "

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
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}

printf "All is good."
echo ""

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

if [[ -z "${MIGRATION_STRATEGY}" ]]; then
    MIGRATION_STRATEGY="at"
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Resolve dependencies on other scripts
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CUSTOM_ERROR_PAGE_PATH="$WORKDIR_PATH/custom_error_page.sh"
if ! [[ -x "$CUSTOM_ERROR_PAGE_PATH" ]]; then
    # Print to stderror
    echo "ERROR: The custom error pages script is not found or it is not executable in path $CUSTOM_ERROR_PAGE_PATH" >&2
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Install ingress-nginx will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  NSG_NAME                         : $NSG_NAME"
echo -e "   -  VNET_NAME                        : $VNET_NAME"
echo -e "   -  SUBNET_NAME                      : $SUBNET_NAME"
echo -e ""
echo -e "   > OPTIONS:"
echo -e "   -  MIGRATION_STRATEGY               : $MIGRATION_STRATEGY"
echo -e "   -  USER_PROMPT                      : $USER_PROMPT"
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
### CLUSTER?
###

kubectl_context="$(kubectl config current-context)"

if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}" ]; then
    echo "kubectl is ready..."
else
    echo "ERROR: Please set your kubectl current-context to be ${CLUSTER_NAME}" >&2
    exit 1
fi

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Create secret required by ingress-nginx
###

echo "Install secret ingress-ip in cluster"

if [[ "${MIGRATION_STRATEGY}" == "aa" ]]; then

    # Path to Public IP Prefix which contains the public inbound IPs
    IPPRE_INGRESS_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP_COMMON/providers/Microsoft.Network/publicIPPrefixes/$AZ_IPPRE_INBOUND_NAME"

    # list of AVAILABLE public ips assigned to the Radix Zone
    echo "Getting list of available public ingress ips in $RADIX_ZONE..."
    AVAILABLE_INGRESS_IPS=$(az network public-ip list --query "[?publicIPPrefix.id=='${IPPRE_INGRESS_ID}' && ipConfiguration.resourceGroup==null].{name:name, id:id, ipAddress:ipAddress}")

    # Select first available ingress ip
    SELECTED_INGRESS_IP="$(echo "$AVAILABLE_INGRESS_IPS" | jq '.[0]')"

    if [[ "$AVAILABLE_INGRESS_IPS" == "[]" ]]; then
        echo "ERROR: Query returned no ips. Please check the variable AZ_IPPRE_INBOUND_NAME in RADIX_ZONE_ENV and that the IP-prefix exists. Exiting..." >&2
        exit 1
    elif [[ -z $AVAILABLE_INGRESS_IPS ]]; then
        echo "ERROR: Found no available ips to assign to the destination cluster. Exiting..." >&2
        exit 1
    else
        echo "-----------------------------------------------------------"
        echo ""
        echo "The following public IP(s) are currently available:"
        echo ""
        echo "$AVAILABLE_INGRESS_IPS" | jq -r '.[].name'
        echo ""
        echo "The following public IP will be assigned as inbound IP to the cluster:"
        echo ""
        echo $SELECTED_INGRESS_IP | jq -r '.name'
        echo ""
        echo "-----------------------------------------------------------"
    fi

    echo ""
    USER_PROMPT="true"
    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Is this correct? (Y/n) " yn
            case $yn in
            [Yy]*)
                echo ""
                echo "Sounds good, continuing."
                break
                ;;
            [Nn]*)
                echo ""
                echo "Quitting."
                exit 0
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi
    echo ""

    SELECTED_INGRESS_IP_ID=$(echo $SELECTED_INGRESS_IP | jq -r '.id')
    SELECTED_INGRESS_IP_RAW_ADDRESS="$(az network public-ip show --ids $SELECTED_INGRESS_IP_ID --query ipAddress -o tsv)"
else
    # Create public ingress IP
    CLUSTER_PIP_NAME="pip-radix-ingress-${RADIX_ZONE}-${RADIX_ENVIRONMENT}-${CLUSTER_NAME}"
    IP_EXISTS=$(az network public-ip list \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --query "[?name=='${CLUSTER_PIP_NAME}'].ipAddress" \
        --output tsv \
        --only-show-errors)

    if [[ ! ${IP_EXISTS} ]]; then
        printf "Creating Public Ingress IP... "
        SELECTED_INGRESS_IP_RAW_ADDRESS=$(az network public-ip create \
            --name "${CLUSTER_PIP_NAME}" \
            --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
            --location "${AZ_RADIX_ZONE_LOCATION}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --allocation-method Static \
            --sku Standard \
            --tier Regional \
            --query "publicIp.ipAddress" \
            --output tsv \
            --only-show-errors) || {
            echo "ERROR: Could not create Public IP. Quitting..." >&2
            exit 1
        }
        printf "Done.\n"
    else
        SELECTED_INGRESS_IP_RAW_ADDRESS="${IP_EXISTS}"
    fi
fi

# create nsg rule, update subnet.
# Create network security group rule
printf "Creating azure NSG rule %s-rule... " "${NSG_NAME}"
az network nsg rule create \
    --nsg-name "${NSG_NAME}" \
    --name "${NSG_NAME}-rule" \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --destination-address-prefixes "${SELECTED_INGRESS_IP_RAW_ADDRESS}" \
    --destination-port-ranges 80 443 \
    --access "Allow" \
    --direction "Inbound" \
    --priority 100 \
    --protocol Tcp \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --output none \
    --only-show-errors

printf "Done.\n"

printf "    Updating subnet %s to associate NSG... " "${SUBNET_NAME}"
az network vnet subnet update \
    --vnet-name "${VNET_NAME}" \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --name "${SUBNET_NAME}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --network-security-group "${NSG_NAME}" \
    --output none \
    --only-show-errors || { echo "ERROR: Could not update subnet." >&2; }
printf "Done.\n"

kubectl create namespace ingress-nginx --dry-run=client -o yaml |
    kubectl apply -f -

kubectl create secret generic ingress-nginx-raw-ip --namespace ingress-nginx \
    --from-literal=rawIp=$SELECTED_INGRESS_IP_RAW_ADDRESS \
    --dry-run=client -o yaml |
    kubectl apply -f -

echo "controller:
  service:
    loadBalancerIP: $SELECTED_INGRESS_IP_RAW_ADDRESS" > config

kubectl create secret generic ingress-nginx-ip --namespace ingress-nginx \
    --from-file=./config \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm config

echo "Create custom-backend-errors..."
printf "%s► Execute %s%s\n" "${grn}" "${CUSTOM_ERROR_PAGE_PATH}" "${normal}"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" CLUSTER_NAME="${DEST_CLUSTER}" source "${CUSTOM_ERROR_PAGE_PATH}")
wait # wait for subshell to finish

printf "Done.\n"
