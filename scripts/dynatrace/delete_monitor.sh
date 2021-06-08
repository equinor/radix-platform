#!/bin/bash

#######################################################################################
### PURPOSE
###

# Delete a web application monitor for a given URL. The script will still be injected
# into the page but it will not be registered in Dynatrace.

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Dynatrace has been deployed
# - The web application monitor has been registered

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - APP_URL             : Ex: "console.dev.radix.equinor.com"

#######################################################################################
### HOW TO USE
### 

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env APP_URL="console.dev.radix.equinor.com" ./delete_monitor.sh

#######################################################################################
### START
###

echo ""
echo "Delete Real User Monitoring..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting..."
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting..."
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting..."
    exit 1
}
printf "All is good."
echo ""

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

if [[ -z "$APP_URL" ]]; then
    echo "Please provide APP_URL" >&2
    exit 1
fi

# Get secrets: api-url and tenant-token from keyvault
DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
DYNATRACE_API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)

# Check if web application monitor exists
echo "Get ID of application monitor..."
echo ""
APP_ID="$(curl --request GET \
    --url $DYNATRACE_API_URL/config/v1/applications/web \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --silent | jq -r '.values[] | select(.name=="'$APP_URL'").id')"

if [[ "$APP_ID" == "" ]]; then
    echo "Web application monitor not found. Quitting..."
    exit 1
else
    # Delete monitor. Detection rule is automatically deleted along with the application monitor.
    echo "Web application monitor found. Proceed to delete monitor."
    echo ""
    DELETE_APP="$(curl --request DELETE \
        --url $DYNATRACE_API_URL/config/v1/applications/web/$APP_ID \
        --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
        --silent \
        --write-out '%{http_code}' | jq -r)"

    if [[ $DELETE_APP == 204 ]]; then
        echo "Successfully deleted application monitor."
    else
        echo "Deletion of application monitor failed: $DELETE_APP"
        exit 1
    fi

fi

