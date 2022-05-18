#!/usr/bin/env bash

#######################################################################################
### PURPOSE
### 

# Bootstrap radix zone infrastructure for "playground.radix.equinor.com"


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

# RADIX_ZONE_ENV=../radix_zone_playground.env ./bootstrap.sh


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap of Radix Zone... "


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
echo -e "Bootstrap radix zone will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_DNS                  : $AZ_RESOURCE_DNS"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

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
### SUPPORT FUNCS
###

function assignRoleForResourceToUser() {
   local ROLE="${1}"
   local ROLE_SCOPE="${2}"
   local USER_ID="$(az ad sp show --id http://${3} --query appId --output tsv)"

   # Delete any existing roles before creating new roles
   az role assignment delete --assignee "${USER_ID}" --scope "${ROLE_SCOPE}" 2>&1 >/dev/null
   az role assignment create --assignee "${USER_ID}" --role "${ROLE}" --scope "${ROLE_SCOPE}" 2>&1 >/dev/null   
}


#######################################################################################
### DNS ZONE
###

echo ""

# Note - AZ DNS Zones locations are "global", meaning you cannot set a location.
echo "Azure DNS: Creating ${AZ_RESOURCE_DNS}..."
az network dns zone create -g "${AZ_RESOURCE_GROUP_COMMON}" -n "${AZ_RESOURCE_DNS}" 2>&1 >/dev/null
echo "...Done."

# Permissions
ROLE_SCOPE="$(az network dns zone show --name ${AZ_RESOURCE_DNS} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

echo "Azure DNS: Update permissions for SP ${AZ_SYSTEM_USER_DNS}..."
assignRoleForResourceToUser "DNS Zone Contributor" "${ROLE_SCOPE}" "${AZ_SYSTEM_USER_DNS}"
echo "...Done."


#######################################################################################
### END
###

echo ""
echo "Domain name delegation is a manual step."
echo "See how to in https://github.com/equinor/radix-private/blob/master/docs/infrastructure/dns.md#how-to-delegate-from-prod-to-dev-or-playground"

echo ""
echo "Bootstrap done!"
