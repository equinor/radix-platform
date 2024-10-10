#!/usr/bin/env bash

function updateComponentEnvVar() {
    local radix_api_fqdn="$1"
    local app="$2"
    local env="$3"
    local component="$4"
    local var="$5"
    local value="$6"

    local access_token=$(az account get-access-token --resource "6dae42f8-4368-4678-94ff-3960e28e3630" | jq -r '.accessToken')
    if [[ -z ${access_token} ]]; then
        echo "ERROR: Could not get access token for Radix API." >&2
        return 1
    fi

    if [[ $STAGING == true ]]; then
        curl_command="curl --cacert /usr/local/share/ca-certificates/letsencrypt-stg-root-x1.pem"
    else
        STAGING=false
        curl_command="curl"
    fi

    local max_retries=15
    local try_nr=0
    printf "Sending PATCH request to Radix API..."

    while true; do
        $curl_command \
            -X PATCH "https://${radix_api_fqdn}/api/v1/applications/${app}/environments/${env}/components/${component}/envvars" \
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
