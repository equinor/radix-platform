#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Bootstrap radix managed identities: create them and store credentials in az keyvault


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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap_managed_identities.sh


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap Radix Managed Identities... "


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
echo -e "Bootstrap Radix Managed Identities will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                               : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION                   : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  AZ_RESOURCE_GROUP_COMMON                 : $AZ_RESOURCE_GROUP_COMMON"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                          : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                                  : $(az account show --query user.name -o tsv)"
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

echo ""


#######################################################################################
### Create managed identities
###
for name in $MI_AKS $MI_AKSKUBELET $MI_CERT_MANAGER
do
    printf "Working on \"${name}\": Creating managed identity..."
    # check if managed identity exists...
    TestMI="$(az identity show --name $name --resource-group $AZ_RESOURCE_GROUP_COMMON --output tsv 2> /dev/null)"
    if [ ! -z "$TestMI" ]; then
        printf "exists, skipping.\n"
        continue
    fi
    az identity create --name $name --resource-group $AZ_RESOURCE_GROUP_COMMON >/dev/null
    printf "Done.\n"
done

#######################################################################################
### ADD ROLE ASSIGNMENTS
###

# Role assignments for aad-pod-identity
# NOTE: It takes some time for the identities to be registered, so a check should be created here.
SUBSCRIPTION_ID="$(az account show --query id -otsv)"
for name in $MI_AKS $MI_AKSKUBELET
do
    printf "Adding role assignment for \"${name}\"..."
    IDENTITY_ID="$(az identity show --resource-group $AZ_RESOURCE_GROUP_COMMON --name $name --query clientId -o tsv)"
    az role assignment create --role "Contributor" --assignee $IDENTITY_ID --scope /subscriptions/$SUBSCRIPTION_ID >/dev/null # grant access to whole subscription
    printf "Done.\n"
done

# Role assignments for cert-manager
for name in $MI_CERT_MANAGER
do
    printf "Adding role assignment for \"${name}\"..."
    IDENTITY="$(az identity show --name $name --resource-group $AZ_RESOURCE_GROUP_COMMON --output json)"
    # Gets principalId to use for role assignment
    PRINCIPAL_ID=$(echo $IDENTITY | jq -r '.principalId')
    # Get existing DNS Zone Id
    ZONE_ID=$(az network dns zone show --name ${AZ_RESOURCE_DNS} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" -o tsv)
    # Create role assignment
    az role assignment create --assignee $PRINCIPAL_ID --role "DNS Zone Contributor"  --scope $ZONE_ID >/dev/null
    printf "...Done\n"
done

#######################################################################################
### END
###


echo ""
echo "Bootstrap of Radix Managed Identities done!"