#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Provision all az resources required to be able to use Velero in a radix cluster.

# Velero require az role Contributor for the resource group that contains the storage.
# Due to that requirement and because we do not want to run the risk of anything else touching the backups,
# we will set everything up in a new resource group dedicated to velero.


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2|c3

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
### 

# RADIX_ZONE=dev ./bootstrap.sh


#######################################################################################
### KNOWN ISSUES
### 

# You have to manually add owners to the service principal.
# See https://github.com/Azure/azure-cli/issues/9250



#######################################################################################
### START
### 

echo "Bootstrap Velero infrastructure..."


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
printf "Done."
echo ""


#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
fi

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh


#######################################################################################
### Environment
###
printf "\n%s► Read YAML configfile $RADIX_ZONE"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "\n%s► Read terraform variables and configuration"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
RADIX_ENVIRONMENT=$(yq '.radix_environment' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
AZ_VELERO_RESOURCE_GROUP=$(jq -r .common_rg <<< "$RADIX_RESOURCE_JSON")
AZ_VELERO_STORAGE_ACCOUNT_ID=$(jq -r .velero_sa <<< "$RADIX_RESOURCE_JSON")
#######################################################################################
### Prepare az session
###

echo ""
printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done."
echo ""

exit_if_user_does_not_have_required_ad_role


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap Velero will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_VELERO_RESOURCE_GROUP         : $AZ_VELERO_RESOURCE_GROUP"
echo -e "   -  AZ_VELERO_STORAGE_ACCOUNT_ID     : $AZ_VELERO_STORAGE_ACCOUNT_ID"
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
    echo ""
fi

#######################################################################################
### Replaced by Terraform
### 

