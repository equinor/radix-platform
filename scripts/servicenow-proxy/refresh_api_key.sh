#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Update keyvault with new API key.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2
# - API_KEY             : The API key

# Optional:
# - USE_SECONDARY_API_KEY : Update keyvault secret holding the secondary key? true/false. Default is false.

#######################################################################################
### HOW TO USE
###

# Example 1: Update keyvault secret holding primary API key:
# RADIX_ZONE=dev API_KEY=the_key ./refresh_api_key.sh

# Example 2: Update keyvault secret holding primary API key, using a subshell to avoid polluting parent shell
# (RADIX_ZONE=dev API_KEY=the_key ./refresh_api_key.sh)

# Example 3: Update keyvault secret holding secondary API key:
# RADIX_ZONE=dev USE_SECONDARY_API_KEY=true API_KEY=the_key ./refresh_api_key.sh

# Example 4: Update keyvault secret holding secondary API key, using a subshell to avoid polluting parent shell
# (RADIX_ZONE=dev USE_SECONDARY_API_KEY=true API_KEY=the_key ./refresh_api_key.sh)

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

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
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
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
KV_SECRET_SERVICENOW_API_KEY="servicenow-api-key"
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

EXPIRY_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" --date="$KV_EXPIRATION_TIME") # The API key has no real expiration date

az keyvault secret set \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" \
    --name "${KV_SECRET_SERVICENOW_API_KEY}" \
    --value "${API_KEY}" \
    --expires "${EXPIRY_DATE}" --output none || exit

printf "Done.\n"
