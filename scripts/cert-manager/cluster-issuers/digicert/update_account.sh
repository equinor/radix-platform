#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Store Digicert ACME external account info in Key Vault


#######################################################################################
### PRECONDITIONS
### 

# - User has permission to write key vault secret


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV        : Path to *.env file
# - ACME_ACCOUNT_KID      : ACME account key ID
# - ACME_ACCOUNT_HMAC_KEY : ACME account HMAC key
# - ACME_ACCOUNT_EMAIL    : ACME account email (must be the email registered for the Digicert account)
# - ACME_SERVER           : ACME server URI

# Optional:
# - USER_PROMPT           : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
### 

# Normal usage
# RADIX_ZONE=dev ACME_ACCOUNT_KID=<kid> ACME_ACCOUNT_HMAC_KEY=<hmac> ACME_ACCOUNT_EMAIL=any@equinor.com ACME_SERVER=https://acme.digicert.com/v2/acme/directory/ ./update_account.sh


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap of DigiCert secrets for Flux... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for necessary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nERROR: jq not found in PATH. Exiting..." >&2;  exit 1; }
printf "All is good."
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

if [[ -z "$ACME_ACCOUNT_KID" ]]; then
    echo "ERROR: Please provide ACME_ACCOUNT_KID" >&2
    exit 1
fi

if [[ -z "$ACME_ACCOUNT_HMAC_KEY" ]]; then
    echo "ERROR: Please provide ACME_ACCOUNT_HMAC_KEY" >&2
    exit 1
fi

if [[ -z "$ACME_ACCOUNT_EMAIL" ]]; then
    echo "ERROR: Please provide ACME_ACCOUNT_EMAIL" >&2
    exit 1
fi

if [[ -z "$ACME_SERVER" ]]; then
    echo "ERROR: Please provide ACME_SERVER" >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Source util scripts
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
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
DIGICERT_EXTERNAL_ACCOUNT_KV_SECRET="digicert-external-account"
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
echo -e "Store Digicert ACME external account info in Key Vault will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                          : $RADIX_ZONE"
echo -e "   -  AZ_RESOURCE_KEYVAULT                : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  DIGICERT_EXTERNAL_ACCOUNT_KV_SECRET : $DIGICERT_EXTERNAL_ACCOUNT_KV_SECRET"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  ACME_ACCOUNT_KID                    : $ACME_ACCOUNT_KID"
echo -e "   -  ACME_ACCOUNT_HMAC_KEY               : <Redacted>"
echo -e "   -  ACME_ACCOUNT_EMAIL                  : $ACME_ACCOUNT_EMAIL"
echo -e "   -  ACME_SERVER                         : $ACME_SERVER"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                     : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                             : $(az account show --query user.name -o tsv)"
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
### Update Key Vault secret
###

printf "\nUpdating Digicert external account info in Key Vault...\n"

secret=$(jq --null-input -r \
    --arg accountKeyID "$ACME_ACCOUNT_KID" \
    --arg accountHMACKey "$ACME_ACCOUNT_HMAC_KEY" \
    --arg accountEmail "$ACME_ACCOUNT_EMAIL" \
    --arg acmeServer "$ACME_SERVER" \
    '{accountKeyID: $accountKeyID, accountHMACKey: $accountHMACKey, accountEmail: $accountEmail, acmeServer: $acmeServer}'
) || exit

# Calculate expiry date 1 year from now on macOS
EXPIRY_DATE=$(date -v+1y -u +"%Y-%m-%dT%H:%M:%SZ")

az keyvault secret set --only-show-errors \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" \
    --subscription "$AZ_SUBSCRIPTION_ID" \
    --name "${DIGICERT_EXTERNAL_ACCOUNT_KV_SECRET}" \
    --value "${secret}" \
    --expires "$EXPIRY_DATE" \
    2>&1 >/dev/null || exit

echo ""
printf "Updating Digicert external account info done!\n"
