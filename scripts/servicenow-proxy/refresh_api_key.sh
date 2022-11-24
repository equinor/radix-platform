#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Update keyvault with new API key.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - API_KEY             : The API key

# Optional:
# - USE_SECONDARY_API_KEY : Update keyvault secret holding the secondary key? true/false. Default is false.

#######################################################################################
### HOW TO USE
###

# Example 1: Update keyvault secret holding primary API key:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env API_KEY=the_key ./refresh_api_key.sh

# Example 2: Update keyvault secret holding primary API key, using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env API_KEY=the_key ./refresh_api_key.sh)

# Example 3: Update keyvault secret holding secondary API key:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env USE_SECONDARY_API_KEY=true API_KEY=the_key ./refresh_api_key.sh

# Example 4: Update keyvault secret holding secondary API key, using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env USE_SECONDARY_API_KEY=true API_KEY=the_key ./refresh_api_key.sh)

#######################################################################################
### START
###

echo ""
echo "Update API key in keyvault"

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Set default values for optional input
###

USER_PROMPT=${USER_PROMPT:=true}
USE_SECONDARY_API_KEY=${USE_SECONDARY_API_KEY:=false}

# Validate input

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

if [[ -z "$API_KEY" ]]; then
    echo "ERROR: Please provide API_KEY" >&2
    exit 1
fi

VALID_USE_SECONDARY_API_KEY=(true false)
if [[ ! " ${VALID_USE_SECONDARY_API_KEY[*]} " =~ " $USE_SECONDARY_API_KEY " ]]; then
    echo "ERROR: USE_SECONDARY_API_KEY must be true or false."  >&2
    exit 1
fi

#######################################################################################
### Build keyvault secret name based on input
###

if [[ $USE_SECONDARY_API_KEY == true ]]; then
    KV_SECRET_SERVICENOW_API_KEY+="-secondary"
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
echo -e "Update API key in keyvault:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  KEYVAULT_SECRET                  : $KV_SECRET_SERVICENOW_API_KEY"
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

printf "Updating API key in keyvault... "

expiration_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ" --date="12 months") # The API key has no real expiration date

az keyvault secret set \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" \
    --name "${KV_SECRET_SERVICENOW_API_KEY}" \
    --value "${API_KEY}" \
    --expires "${expiration_date}" --output none || exit

printf "Done.\n"
