#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Restore Private Endpoints from definitions stored in key vault.

#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV                  : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix_zone_dev.env ./restore_private_endpoint.sh

#######################################################################################
### START
###

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

CREATE_PRIVATE_ENDPOINT_SCRIPT="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/radix-zone/private-endpoint-infrastructure/create_private_endpoint.sh"
if ! [[ -x "$CREATE_PRIVATE_ENDPOINT_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The create private endpoint script is not found or it is not executable in path $CREATE_PRIVATE_ENDPOINT_SCRIPT" >&2
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

temp_file="/tmp/$(uuidgen)"

az keyvault secret show \
        --vault-name ${AZ_RESOURCE_KEYVAULT} \
        --name ${RADIX_PE_KV_SECRET_NAME} \
        | jq '.value | fromjson' > ${temp_file}

jq -c '.[]' $temp_file | while read i; do
    pe_name=$(echo $i | jq .private_endpoint_name --raw-output)
    pe_rg=$(echo $i | jq .private_endpoint_resource_group --raw-output)
    pe_location=$(echo $i | jq .private_endpoint_location --raw-output)
    target_resource_id=$(echo $i | jq .target_resource_id --raw-output)
    target_subresource=$(echo $i | jq .target_subresource --raw-output)
    pe_ip_address=$(echo $i | jq .ip_address --raw-output)
    RADIX_ZONE_ENV=${RADIX_ZONE_ENV} USER_PROMPT=false PRIVATE_ENDPOINT_NAME=${pe_name} TARGET_RESOURCE_RESOURCE_ID=$target_resource_id TARGET_SUBRESOURCE=${target_subresource} IP_ADDRESS=${pe_ip_address} ${CREATE_PRIVATE_ENDPOINT_SCRIPT}
done

rm $temp_file
echo "Done restoring all private endpoints from ${RADIX_PE_KV_SECRET_NAME}."