#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix environment infrastructure shared by all radix-zones


#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix_zone_dev.env ./bootstrap.sh


#######################################################################################
### START
###

echo ""
echo "Start bootstrap of base infrastructure... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { printf "\n\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### Read inputs and configs
###

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
fi
AD_APP_MANIFEST_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/manifest-server.json"
if [[ ! -f "$AD_APP_MANIFEST_PATH" ]]; then
   echo "The dependency AD_APP_MANIFEST_PATH=$AD_APP_MANIFEST_PATH is invalid, the file does not exist." >&2
   exit 1
fi


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

exit_if_user_does_not_have_required_ad_role


#######################################################################################
### Verify task at hand
###

printf "\n"
printf "\nBootstrap of base infrastructure will use the following configuration:"
printf "\n"
printf "\n   > WHERE:"
printf "\n   ------------------------------------------------------------------"
printf "\n   -  RADIX_ZONE                                  : $RADIX_ZONE"
printf "\n   -  AZ_RADIX_ZONE_LOCATION                      : $AZ_RADIX_ZONE_LOCATION"
printf "\n   -  RADIX_ENVIRONMENT                           : $RADIX_ENVIRONMENT"
printf "\n"
printf "\n   > WHAT:"
printf "\n   -------------------------------------------------------------------"
printf "\n   -  AZ_RESOURCE_GROUP_CLUSTERS                  : $AZ_RESOURCE_GROUP_CLUSTERS"
printf "\n   -  AZ_RESOURCE_GROUP_COMMON                    : $AZ_RESOURCE_GROUP_COMMON"
printf "\n   -  AZ_RESOURCE_GROUP_MONITORING                : $AZ_RESOURCE_GROUP_MONITORING"
printf "\n"
printf "\n   -  AZ_RESOURCE_KEYVAULT                        : $AZ_RESOURCE_KEYVAULT"
printf "\n   -  AZ_IPPRE_OUTBOUND_NAME                      : $AZ_IPPRE_OUTBOUND_NAME"
printf "\n   -  AZ_IPPRE_OUTBOUND_IP_PREFIX                 : $AZ_IPPRE_OUTBOUND_IP_PREFIX"
printf "\n   -  AZ_IPPRE_OUTBOUND_LENGTH                    : $AZ_IPPRE_OUTBOUND_LENGTH"
printf "\n   -  AZ_IPPRE_INBOUND_NAME                       : $AZ_IPPRE_INBOUND_NAME"
printf "\n   -  AZ_IPPRE_INBOUND_LENGTH                     : $AZ_IPPRE_INBOUND_LENGTH"
printf "\n   -  AZ_RESOURCE_CONTAINER_REGISTRY              : $AZ_RESOURCE_CONTAINER_REGISTRY"
printf "\n   -  AZ_RESOURCE_DNS                             : $AZ_RESOURCE_DNS"
printf "\n"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER    : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD      : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
printf "\n   -  AZ_SYSTEM_USER_DNS                          : $AZ_SYSTEM_USER_DNS"
printf "\n"
printf "\n   > WHO:"
printf "\n   -------------------------------------------------------------------"
printf "\n   -  AZ_SUBSCRIPTION                             : $(az account show --query name -otsv)"
printf "\n   -  AZ_USER                                     : $(az account show --query user.name -o tsv)"
printf "\n"

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi


#######################################################################################
### Resource groups
###

function create_resource_groups() {
    printf "Creating all resource groups..."
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_CLUSTERS}" --output none
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_COMMON}" --output none
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_MONITORING}" --output none
    printf "...Done\n"
}


#######################################################################################
### Common resources
###

function create_common_resources() {
    printf "Creating key vault: ${AZ_RESOURCE_KEYVAULT}...\n"
    az keyvault create --name "${AZ_RESOURCE_KEYVAULT}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --output none
    printf "...Done\n"

    printf "Creating Azure DNS: ${AZ_RESOURCE_DNS}\n"
    az network dns zone create -g "${AZ_RESOURCE_GROUP_COMMON}" -n "${AZ_RESOURCE_DNS}" --output none
    printf "...Done\n"
    # DNS CAA
    if [ "$RADIX_ENVIRONMENT" = "prod" ]; then
        printf "Adding CAA records..."
        az network dns record-set caa add-record -g "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "letsencrypt.org" --output none
        az network dns record-set caa add-record -g "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "digicert.com" --output none
        az network dns record-set caa add-record -g "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "godaddy.com" --output none
        printf "...Done\n"
    fi
    ../private-endpoint-infrastructure/bootstrap.sh
}

function create_outbound_public_ip_prefix() {
    # Create public ip prefixes
    if [[ -n $AZ_IPPRE_OUTBOUND_NAME ]]; then
        if [[ -z $(az network public-ip prefix show --name "${AZ_IPPRE_OUTBOUND_NAME}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "name" -otsv 2>/dev/null) ]]; then
            printf "Public IP Prefix ${AZ_IPPRE_OUTBOUND_NAME} does not exist.\n"
            if [[ $USER_PROMPT == true ]]; then
                while true; do
                    read -p "Create Public IP Prefix: ${AZ_IPPRE_OUTBOUND_NAME}? (Y/n) " yn
                    case $yn in
                        [Yy]* ) break;;
                        [Nn]* ) echo ""; echo "Return."; return;;
                        * ) echo "Please answer yes or no.";;
                    esac
                done
                printf "Creating Public IP Prefix: ${AZ_IPPRE_OUTBOUND_NAME}...\n"
                az network public-ip prefix create \
                    --length "${AZ_IPPRE_OUTBOUND_LENGTH}" \
                    --name "${AZ_IPPRE_OUTBOUND_NAME}" \
                    --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
                    --subscription "${AZ_SUBSCRIPTION_ID}" \
                    --output none
                printf "...Done.\n"
            fi
        else
            printf "Public IP Prefix ${AZ_IPPRE_OUTBOUND_NAME} already exists."
        fi
        # Create IPs
        echo "Creating IPs in Public IP Prefix ${AZ_IPPRE_OUTBOUND_NAME}..."
        IPPRE_OUTBOUND_IP_NUMBER=$(az network public-ip prefix show \
            --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
            --name ${AZ_IPPRE_OUTBOUND_NAME} \
            --subscription ${AZ_SUBSCRIPTION_ID} \
            --query publicIpAddresses |
            jq -r .[].id |
            wc -l |
            sed 's/^ *//g')
        while true; do
            # Get current number of IPs, add trailing 0s and increment by 1
            IPPRE_OUTBOUND_IP_NUMBER=$(printf %03d $(($IPPRE_OUTBOUND_IP_NUMBER + 1 )) )
            IP_NAME="${AZ_IPPRE_OUTBOUND_IP_PREFIX}-${IPPRE_OUTBOUND_IP_NUMBER}"
            if [[ $(az network public-ip create \
                --public-ip-prefix /subscriptions/$AZ_SUBSCRIPTION_ID/resourcegroups/$AZ_RESOURCE_GROUP_COMMON/providers/microsoft.network/publicipprefixes/$AZ_IPPRE_OUTBOUND_NAME \
                --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
                --name ${IP_NAME} \
                --subscription ${AZ_SUBSCRIPTION_ID} \
                --sku Standard \
                2>/dev/null) ]]; then
                echo "Created ip $IP_NAME"
            else
                echo "IPs have been created."
                break
            fi
        done
    else
        printf "Variable AZ_IPPRE_OUTBOUND_NAME not defined."
    fi
}

function create_inbound_public_ip_prefix() {
    if [[ -n $AZ_IPPRE_INBOUND_NAME ]]; then
        if [[ -z $(az network public-ip prefix show --name "${AZ_IPPRE_INBOUND_NAME}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "name" -otsv 2>/dev/null) ]]; then
            printf "Public IP Prefix ${AZ_IPPRE_INBOUND_NAME} does not exist.\n"
            if [[ $USER_PROMPT == true ]]; then
                while true; do
                    read -p "Create Public IP Prefix: ${AZ_IPPRE_INBOUND_NAME}? (Y/n) " yn
                    case $yn in
                        [Yy]* ) break;;
                        [Nn]* ) echo ""; echo "Return."; return;;
                        * ) echo "Please answer yes or no.";;
                    esac
                done
                printf "Creating Public IP Prefix: ${AZ_IPPRE_INBOUND_NAME}...\n"
                az network public-ip prefix create \
                    --length "${AZ_IPPRE_INBOUND_LENGTH}" \
                    --name "${AZ_IPPRE_INBOUND_NAME}" \
                    --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
                    --subscription "${AZ_SUBSCRIPTION_ID}" \
                    --output none
                printf "...Done.\n"
            fi
        else
            printf "Public IP Prefix ${AZ_IPPRE_INBOUND_NAME} already exists."
        fi
        # Create IPs
        echo "Creating IPs in Public IP Prefix ${AZ_IPPRE_INBOUND_NAME}..."
        IPPRE_INBOUND_IP_NUMBER=$(az network public-ip prefix show \
            --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
            --name ${AZ_IPPRE_INBOUND_NAME} \
            --subscription ${AZ_SUBSCRIPTION_ID} \
            --query publicIpAddresses |
            jq -r .[].id |
            wc -l |
            sed 's/^ *//g')
        while true; do
            # Get current number of IPs, add trailing 0s and increment by 1
            IPPRE_INBOUND_IP_NUMBER=$(printf %03d $(($IPPRE_INBOUND_IP_NUMBER + 1 )) )
            IP_NAME="${AZ_IPPRE_INBOUND_IP_PREFIX}-${IPPRE_INBOUND_IP_NUMBER}"
            if [[ $(az network public-ip create \
                --public-ip-prefix /subscriptions/$AZ_SUBSCRIPTION_ID/resourcegroups/$AZ_RESOURCE_GROUP_COMMON/providers/microsoft.network/publicipprefixes/$AZ_IPPRE_INBOUND_NAME \
                --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
                --name ${IP_NAME} \
                --subscription ${AZ_SUBSCRIPTION_ID} \
                --sku Standard \
                2>/dev/null) ]]; then
                echo "Created ip $IP_NAME"
            else
                echo "IPs have been created."
                break
            fi
        done
    else
        printf "Variable AZ_IPPRE_INBOUND_NAME not defined."
    fi
}

function create_acr() {
    # Create ACR
    if [[ -z $(az acr show --name "${AZ_RESOURCE_CONTAINER_REGISTRY}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "name" -otsv 2>/dev/null) ]]; then
        printf "Azure Container Registry ${AZ_RESOURCE_CONTAINER_REGISTRY} does not exist.\n"
        if [[ $USER_PROMPT == true ]]; then
            while true; do
                read -p "Create Azure Container Registry: ${AZ_RESOURCE_CONTAINER_REGISTRY}? (Y/n) " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo ""; echo "Return."; return;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi

        printf "Creating Azure Container Registry: ${AZ_RESOURCE_CONTAINER_REGISTRY}...\n"
        az acr create \
            --name "${AZ_RESOURCE_CONTAINER_REGISTRY}" \
            --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
            --sku "Premium" \
            --location "${AZ_RADIX_ZONE_LOCATION}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --default-action "Deny" \
            --public-network-enabled "true" \
            --output none
        printf "...Done\n"
    else
        printf "ACR ${AZ_RESOURCE_CONTAINER_REGISTRY} already exists.\n"
    fi
}

function set_permissions_on_acr() {
    local scope
    scope="$(az acr show --name ${AZ_RESOURCE_CONTAINER_REGISTRY} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

    # Available roles
    # https://github.com/Azure/acr/blob/master/docs/roles-and-permissions.md
    # Note that to be able to use "az acr build" you have to have the role "Contributor".

    local id
    printf "Working on container registry \"${AZ_RESOURCE_CONTAINER_REGISTRY}\": "

    printf "Setting permissions for \"${AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER}\"..." # radix-cr-reader-dev
    id="$(az ad sp list --display-name ${AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER} --query [].appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}" --output none
    # Configure new roles
    az role assignment create --assignee "${id}" --role AcrPull --scope "${scope}" --output none

    printf "Setting permissions for \"${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD}\"..." # radix-cr-cicd-dev
    id="$(az ad sp list --display-name ${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD} --query [].appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}" --output none
    # Configure new roles
    az role assignment create --assignee "${id}" --role Contributor --scope "${scope}" --output none


    printf "...Done\n"
}

function set_permissions_on_dns() {
    local scope
    local id
    local dns # Optional input 1

    if [ -n "$1" ]; then
        dns="$1"
    else
        dns="$AZ_RESOURCE_DNS"
    fi

    if [ "$RADIX_ENVIRONMENT" = "classic" ]; then
        # Use Managed Identity.
        # https://cert-manager.io/docs/configuration/acme/dns01/azuredns/#managed-identity-using-aad-pod-identities

        printf "Azure dns zone: Setting permissions for \"${AZ_MANAGED_IDENTITY_NAME}\" on \"${dns}\"..."

        # Choose a unique Identity name and existing resource group to create identity in.
        IDENTITY="$(az identity show --name $AZ_MANAGED_IDENTITY_NAME --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --output json)"
        # Gets principalId to use for role assignment
        PRINCIPAL_ID=$(echo $IDENTITY | jq -r '.principalId')
        # Get existing DNS Zone Id
        ZONE_ID=$(az network dns zone show --name ${dns} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" -o tsv)
        # Create role assignment
        az role assignment create --assignee $PRINCIPAL_ID --role "DNS Zone Contributor"  --scope $ZONE_ID
        printf "...Done\n"
    else
        # Use service principle.

        scope="$(az network dns zone show --name ${dns} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

        # Grant 'DNS Zone Contributor' permissions to a specific zone
        # https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#dns-zone-contributor
        printf "Azure dns zone: Setting permissions for \"${AZ_SYSTEM_USER_DNS}\" on \"${dns}\"..."
        id="$(az ad sp list --display-name ${AZ_SYSTEM_USER_DNS} --query [].appId --output tsv)"
        az role assignment create --assignee "${id}" --role "DNS Zone Contributor" --scope "${scope}" --output none
        printf "...Done\n"
    fi
}


#######################################################################################
### System users
###

function create_base_system_users_and_store_credentials() {
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER" "Service principal that provide read-only access to container registry"
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD" "Service principal that provide push, pull, build in container registry"
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_DNS" "Can make changes in the DNS zone"
}


#######################################################################################
### MAIN
###

create_resource_groups
create_common_resources
create_outbound_public_ip_prefix
create_inbound_public_ip_prefix
create_acr
create_base_system_users_and_store_credentials
set_permissions_on_acr
set_permissions_on_dns


#######################################################################################
### END
###

echo ""
echo "Azure DNS Zone delegation is a manual step."
echo "See how to in https://github.com/equinor/radix-private/blob/master/docs/infrastructure/dns.md#how-to-delegate-from-prod-to-dev-or-playground"

echo ""
echo "Bootstrap of base infrastructure done!"