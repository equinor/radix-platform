#!/usr/bin/env bash

function updateComponentEnvVar() {
    local resource="$1"
    local radix_api_fqdn="$2"
    local app="$3"
    local env="$4"
    local component="$5"
    local var="$6"
    local value="$7"

    local access_token=$(az account get-access-token --resource "${resource}" | jq -r '.accessToken')
    if [[ -z ${access_token} ]]; then
        echo "ERROR: Could not get access token for Radix API." >&2
        return 1
    fi

    local max_retries=15
    local try_nr=0
    printf "Sending PATCH request to Radix API..."
    
    while true; do
        curl -X PATCH "https://${radix_api_fqdn}/api/v1/applications/${app}/environments/${env}/components/${component}/envvars" \
            -f \
            -H "accept: application/json" \
            -H "Authorization: Bearer ${access_token}" \
            -H "Content-Type: application/json" \
            -d "[ { \"name\": \"${var}\", \"value\": \"${value}\" }]"
        local curl_exit_code=$?
        if [[ $curl_exit_code != 0 ]]; then
            try_nr=$(($try_nr + 1))
            if [ "$try_nr" -lt $max_retries ]; then
                local sleep_seconds=$(($try_nr * 4))
                echo -e "\nERROR: Patch request to ${radix_api_fqdn} failed. Sleeping ${sleep_seconds} seconds and retrying..." >&2
                sleep $sleep_seconds
                continue
            else
                echo -e "\nERROR: Patch request to ${radix_api_fqdn} failed. Out of retries, exiting." >&2
                return 1
            fi
        fi
        
        break
    done

    printf " Done.\n"
}
