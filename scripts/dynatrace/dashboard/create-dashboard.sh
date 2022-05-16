#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create a dashboard in Dynatrace by sending a request with a payload to the Dynatrace API

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

# RADIX_ZONE_ENV=../../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./create-dashboard.sh

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

function create_dashboard_json (){
    local radix_env="$1"
    local cluster_name="$2"
    local offset="$3"

    export DASHBOARD_RADIX_ENV="${radix_env^}"
    export DASHBOARD_NAME="Radix cluster overview $cluster_name"
    export DASHBOARD_CLUSTER_NAME="radix-${radix_env}-$cluster_name"
    export START_POS_TOP="$offset"

    WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DASHBOARD_JSON_TEMPLATE="$WORKDIR_PATH/radix-dashboard-template.json"
    TEMP_DASHBOARD_JSON="dashboard.json"
    test -f "$TEMP_DASHBOARD_JSON" && rm "$TEMP_DASHBOARD_JSON" # Delete dashboard JSON file if it exists.

    # Substitute variables in template file with values into dashboard JSON file.
    envsubst < $DASHBOARD_JSON_TEMPLATE > $TEMP_DASHBOARD_JSON

    printf "Get API token..."
    API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)
    DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
    printf " done.\n"

    # Check if dashboard exists, get id
    response="$(curl -k -sS -X GET "${DYNATRACE_API_URL}/config/v1/dashboards?tags=RADIX" \
        -H "accept: application/json; charset=utf-8" \
        -H "Authorization: Api-Token ${API_TOKEN}" \
        -H "Content-Type: application/json; charset=utf-8")"

    if ! echo "$response" | grep -Fq "\"name\":\"${DASHBOARD_NAME}\""; then
        echo "Dashboard does not exist."
        # Create dashboard
        JSON=$(cat $TEMP_DASHBOARD_JSON)

        printf "Send API request (create dashboard)..."
        response="$(curl -k -sS -X POST "${DYNATRACE_API_URL}/config/v1/dashboards" \
            -H "accept: application/json; charset=utf-8" \
            -H "Authorization: Api-Token ${API_TOKEN}" \
            -H "Content-Type: application/json; charset=utf-8" \
            -d "${JSON}")"
        
        # success response: {"id":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx","name":"xxxxx"}
        if echo "$response" | grep -Fq "\"error\""; then
            printf "ERROR: Could not create dashboard. Quitting...\n" >&2
            return
        fi
        printf " done.\n"

        export DASHBOARD_ID=$(echo $response | jq -r '.id')
    else
        echo "Dashboard exists."
        # Update dashboard
        export DASHBOARD_ID=$(echo $response | jq -r '.dashboards[] | select(.name=="Radix dashboard template '$DASHBOARD_RADIX_ENV'").id')
         # Set dashboard id and set tile position before sending the request JSON.
        JSON=$(jq '.id = "'${DASHBOARD_ID}'"' ${TEMP_DASHBOARD_JSON})

        printf "Send API request (update dashboard)..."
        response="$(curl -k -sS -X PUT "${DYNATRACE_API_URL}/config/v1/dashboards/${DASHBOARD_ID}" \
            -H "accept: application/json; charset=utf-8" \
            -H "Authorization: Api-Token ${API_TOKEN}" \
            -H "Content-Type: application/json; charset=utf-8" \
            -d "${JSON}")"

        if echo "$response" | grep -Fq "\"error\""; then
            printf "ERROR: Could not update dashboard. Quitting...\n" >&2
            echo "$response"
            return
        fi
        printf " done.\n"
    fi

    # Update share settings
    PERMISSIONS_JSON_TEMPLATE="$WORKDIR_PATH/radix-dashboard-permissions-template.json"
    TEMP_DASHBOARD_PERMISSIONS_JSON="permissions.json"
    test -f "$TEMP_DASHBOARD_PERMISSIONS_JSON" && rm "$TEMP_DASHBOARD_PERMISSIONS_JSON" # Delete dashboard permissions JSON file if it exists.
    envsubst < $PERMISSIONS_JSON_TEMPLATE > $TEMP_DASHBOARD_PERMISSIONS_JSON # Substitute variables in template file with values into dashboard permissions JSON file.

    JSON=$(cat $TEMP_DASHBOARD_PERMISSIONS_JSON | jq '')

    printf "Send API request (update share settings)..."
    response="$(curl -k -sS -X PUT "${DYNATRACE_API_URL}/config/v1/dashboards/${DASHBOARD_ID}/shareSettings" \
        -H "accept: application/json; charset=utf-8" \
        -H "Authorization: Api-Token ${API_TOKEN}" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "${JSON}")"
    # Check response
    if echo "$response" | grep -Fq "\"error\""; then
        printf "ERROR: Could not update share settings. Quitting...\n" >&2
        return
    fi
    printf " done.\n"

    # Remove temp files
    rm "$TEMP_DASHBOARD_JSON" "$TEMP_DASHBOARD_PERMISSIONS_JSON"
}

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
echo -e "Create dynatrace dashboard will use the following configuration:"
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
create_dashboard_json "$CLUSTER_TYPE" "$CLUSTER_NAME"

# Remove temp files
test -f "$TEMP_DASHBOARD_JSON" && rm "$TEMP_DASHBOARD_JSON"
test -f "$TEMP_DASHBOARD_PERMISSIONS_JSON" && rm "$TEMP_DASHBOARD_PERMISSIONS_JSON"
