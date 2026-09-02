#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# This script will
# - retrieve every app registration owned by the user 
# - check if the app registration name contains Radix
# - use the service principal script to update the owners.

#######################################################################################
### Read inputs and configs
###

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
fi

#######################################################################################
### MAIN
###

while IFS=$'\t' read -r -a line; do
    name=${line}
    if [[ "${name,,}" == *"radix"* ]]; then
        update_ad_app_owners "${name}"
        update_service_principal_owners "${name}"
    fi
done <<< "$(az ad app list --show-mine --query [].displayName --output tsv --only-show-errors)"

unset IFS
