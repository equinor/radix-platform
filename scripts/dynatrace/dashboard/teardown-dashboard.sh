#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Delete a dashboard in Dynatrace by sending a request with a payload to the Dynatrace API

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./teardown-dashboard.sh

#######################################################################################
### START
###

# Required inputs

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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Main function

function delete_dashboard(){
    local cluster_name="$1"

    DASHBOARD_NAME="Radix cluster overview $cluster_name"

    printf "Get API token..."
    API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)
    printf " done.\n"

    # Check if dashboard exists, get id
    response="$(curl -k -sS -X GET "https://spa-equinor.kanari.com/e/eddaec99-38b1-4a9c-9f4c-9148921efa10/api/config/v1/dashboards?tags=RADIX" \
        -H "accept: application/json; charset=utf-8" \
        -H "Authorization: Api-Token ${API_TOKEN}" \
        -H "Content-Type: application/json; charset=utf-8")"

    if ! echo "$response" | grep -Fq "\"name\":\"${DASHBOARD_NAME}\""; then
        echo "ERROR: Dashboard does not exist. Quitting..." >&2
        return
    fi

    DASHBOARD_ID=$(echo $response | jq -r '.dashboards[] | select(.name=="'"${DASHBOARD_NAME}"'").id')

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -p "Delete dashboard \"${DASHBOARD_NAME}\"? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) echo ""; echo "Quitting."; return;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    printf "Send API request (delete dashboard)..."
    response="$(curl -k -sS -X DELETE "https://spa-equinor.kanari.com/e/eddaec99-38b1-4a9c-9f4c-9148921efa10/api/config/v1/dashboards/${DASHBOARD_ID}" \
        -H "accept: application/json; charset=utf-8" \
        -H "Authorization: Api-Token ${API_TOKEN}" \
        -H "Content-Type: application/json; charset=utf-8")"

    if echo "$response" | grep -Fq "\"error\""; then
        printf "ERROR: Could not delete dashboard. Quitting...\n" >&2
        return
    fi
    printf " done.\n"
}

#######################################################################################
### Prepare az session
###

printf "\nLogging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Teardown dynatrace dashboard will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  CLUSTER_TYPE                     : $CLUSTER_TYPE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
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
fi

# Call function
delete_dashboard "$CLUSTER_NAME"
