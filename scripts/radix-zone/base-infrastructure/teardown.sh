#!/usr/bin/env bash

#######################################################################################
### PURPOSE
### 

# Tear down radix zone infrastructure


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

# RADIX_ZONE_ENV=../radix_zone_playground.env ./teardown.sh


#######################################################################################
### START
### 

echo ""
echo "Start tear down of Radix Zone... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
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
printf "\nTear down of base infrastructure will use the following configuration:"
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
printf "\n   -  AZ_RESOURCE_CONTAINER_REGISTRY              : $AZ_RESOURCE_CONTAINER_REGISTRY"
printf "\n   -  AZ_RESOURCE_DNS                             : $AZ_RESOURCE_DNS"
printf "\n   -  AZ_RESOURCE_KEYVAULT                        : $AZ_RESOURCE_KEYVAULT"
printf "\n"
printf "\n   -  AZ_RESOURCE_AAD_SERVER                      : $AZ_RESOURCE_AAD_SERVER"
printf "\n   -  AZ_RESOURCE_AAD_CLIENT                      : $AZ_RESOURCE_AAD_CLIENT"
printf "\n"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER    : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD      : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
printf "\n   -  AZ_SYSTEM_USER_CLUSTER                      : $AZ_SYSTEM_USER_CLUSTER"
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
    echo ""
fi

#######################################################################################
### Remove infrastructure
###

delete_service_principal_and_stored_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
delete_service_principal_and_stored_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
delete_service_principal_and_stored_credentials "$AZ_SYSTEM_USER_CLUSTER"
delete_service_principal_and_stored_credentials "$AZ_SYSTEM_USER_DNS"

delete_ad_app_and_stored_credentials ""$AZ_RESOURCE_AAD_SERVER""
delete_ad_app_and_stored_credentials ""$AZ_RESOURCE_AAD_CLIENT""

# Need to handle key vault separately due to "soft delete" feature
printf "Working in Azure key vault: Deleting ${AZ_RESOURCE_KEYVAULT}...\n"
az keyvault delete -n "${AZ_RESOURCE_KEYVAULT}" --output none
# printf "Purging ${AZ_RESOURCE_KEYVAULT}...\n"
# az keyvault purge -n "${AZ_RESOURCE_KEYVAULT}" --output none
printf "...Done.\n"

printf "Working on resource groups: \n"
printf "Deleting ${AZ_RESOURCE_GROUP_CLUSTERS}...\n"
az group delete --yes --name "${AZ_RESOURCE_GROUP_CLUSTERS}" --output none 
printf "Deleting ${AZ_RESOURCE_GROUP_COMMON}...\n"
az group delete --yes --name "${AZ_RESOURCE_GROUP_COMMON}" --output none
printf "Deleting ${AZ_RESOURCE_GROUP_MONITORING}...\n"
az group delete --yes --name "${AZ_RESOURCE_GROUP_MONITORING}" --output none
printf "...Done.\n"



#######################################################################################
### END
###

echo ""
echo "Teardown done!"