#!/usr/bin/env bash

#######################################################################################
### PURPOSE
### 

# Bootstrap radix zone infrastructure for monitoring, resource gorups, keyvault etc


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

# ./bootstrap.sh env


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap of Monitoring infrastructure.. "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
echo "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
echo "Done.\n"


#######################################################################################
### Read inputs and configs
###
RADIX_ZONE_ENV="../radix_zone_$1.env"

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi


#######################################################################################
### Prepare az session
###

echo "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
echo "Done.\n"


cat << EOF
Will use the following configuration:
    ------------------------------------------------------------------
    -  RADIX_ZONE                       : $RADIX_ZONE
    -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION
    -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT

    -------------------------------------------------------------------
    -  AZ_RESOURCE_GROUP_MONITORING     : $AZ_RESOURCE_GROUP_MONITORING
    -  KEYVAULT                         : $AZ_RESOURCE_MON_KEYVAULT
    -  AD DEV GROUP                     : $AZ_AD_DEV_GROUP
    -  AD OPS GROUP                     : $AZ_AD_OPS_GROUP
    -------------------------------------------------------------------
    -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)
    -  AZ_USER                          : $(az account show --query user.name -o tsv)
EOF


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


### Resource groups
###

function create_resource_groups(){
    echo "Creating resource group..."
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_MONITORING}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none
}

## Create Grafana database

function create_grafana_mysql(){

# TODO
# See https://github.com/equinor/radix-grafana

}

## Create Keyvault

function create_keyvault(){

    echo "Creating key vault: ${AZ_RESOURCE_MON_KEYVAULT}..."
    az keyvault create \
        --name "${AZ_RESOURCE_MON_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_MONITORING}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --enable-purge-protection \
        --only-show-errors
    echo "...Done"

    echo "Set access policy for group Radix Platform Operators in key vault: ${AZ_RESOURCE_KEYVAULT}..."
    az keyvault set-policy \
        --object-id "$(az ad group show --group "${AZ_AD_OPS_GROUP}" --query id --output tsv --only-show-errors)" \
        --name "${AZ_RESOURCE_MON_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_MONITORING}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --certificate-permissions get list update create import delete recover backup restore managecontacts manageissuers getissuers listissuers setissuers deleteissuers \
        --key-permissions get list update create import delete recover backup restore \
        --secret-permissions get list set delete recover backup restore \
        --storage-permissions
    echo "...Done"

    echo "Set access policy for group Radix Platform Developers in key vault: ${AZ_RESOURCE_KEYVAULT}..."

    az keyvault set-policy \
        --object-id "$(az ad group show --group "${AZ_AD_DEV_GROUP}" --query id --output tsv --only-show-errors)" \
        --name "${AZ_RESOURCE_MON_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_MONITORING}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --certificate-permissions get list \
        --key-permissions get list \
        --secret-permissions get list  \
        --storage-permissions \
        --only-show-errors
    echo "...Done"
}


create_resource_groups
create_keyvault
create_monitoring_service_principal "$APP_REGISTRATION_GRAFANA" "Grafana OAuth"
create_grafana_azure_secret "$APP_REGISTRATION_GRAFANA" "radix-grafana-azure" "Grafana Azure secret"
create_grafana_mysql

echo ""
echo "Bootstrap done!"
