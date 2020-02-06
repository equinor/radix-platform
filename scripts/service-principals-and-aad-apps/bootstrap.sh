#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Bootstrap radix service principals: create them and store credentials in az keyvault


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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap radix service principals... "


#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nError: jq not found in PATH. Exiting... " >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### Read inputs and configs
###

# Required inputs

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
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
fi


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
printf "Done.\n"

exit_if_user_does_not_have_required_ad_role



#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap radix service principals will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                               : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION                   : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                        : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
echo -e "   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD   : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
echo -e "   -  AZ_SYSTEM_USER_CLUSTER                   : $AZ_SYSTEM_USER_CLUSTER"
echo -e "   -  AZ_SYSTEM_USER_DNS                       : $AZ_SYSTEM_USER_DNS"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                          : $AZ_SUBSCRIPTION"
echo -e "   -  AZ_USER                                  : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
    echo ""
    echo "Quitting."
    exit 0
    fi
    echo ""
fi

echo ""


#######################################################################################
### Create service principal
###

create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER" "Provide read-only access to container registry"
create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD" "Provide push, pull, build in container registry"
create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CLUSTER" "The AKS service principal"
create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_DNS" "Can make changes in the DNS zone"



#######################################################################################
### END
###


echo ""
echo "Boostrap of radix service principals done!"