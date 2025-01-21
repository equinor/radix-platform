#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Update keyvault with new credentials for Docker Hub whis is used to build 
# .dockerconfigjson in secret default/radix-registry-default-auth.
# This secret is used as imagepullsecret in all components and batch jobs
# to avoid the docker.io ratelimit for anonymous users when pulling images,
# ref: https://docs.docker.com/docker-hub/download-rate-limit/
# The keyvault secrets are synced to the default/radix-registry-default-auth
# secret using external-secrets operator.


#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - USER_NAME           : User name on docker.com
# - ACCESS_TOKEN        : New personal access token for the user

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Please refer to https://github.com/equinor/radix-private/blob/master/docs/infrastructure/container-registries.md#external-container-registries
# to get instructions on how to request a new access token.

# Example:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env USER_NAME=radix ACCESS_TOKEN=dckr_pat_abcd ./update_docker_auth.sh

#######################################################################################
### START
###

echo ""
echo "Update Docker auth in keyvault"

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

if [[ -z "$USER_NAME" ]]; then
    echo "ERROR: Please provide USER_NAME" >&2
    exit 1
fi

if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "ERROR: Please provide ACCESS_TOKEN" >&2
    exit 1
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
echo -e "Update Docker auth in keyvault:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  USER_NAME                        : $USER_NAME"
echo -e "   -  ACCESS_TOKEN                     : <Redacted>"
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

printf "Updating Docker auth in keyvault... "

EXPIRY_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" --date="$KV_EXPIRATION_TIME") # The secrets have no real expiration date

az keyvault secret set \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" \
    --name docker-io-auth-username \
    --value "${USER_NAME}" \
    --expires "${EXPIRY_DATE}" --output none || exit

az keyvault secret set \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" \
    --name docker-io-auth-access-token \
    --value "${ACCESS_TOKEN}" \
    --expires "${EXPIRY_DATE}" --output none || exit

printf "Done.\n"
