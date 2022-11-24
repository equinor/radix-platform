#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Configures the secrets for Radix ServiceNow Proxy on the cluster given the context.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

# Optional:
# - USE_SECONDARY_API_KEY : Use the secondary API key? true/false. Default is false.


#######################################################################################
### HOW TO USE
###

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-2 ./update_secret_for_radix_servicenow_proxy.sh

# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-2 ./update_secret_for_radix_servicenow_proxy.sh)

# Example 1: Use the secondary API key from keyvault
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-2 USE_SECONDARY_API_KEY=true ./update_secret_for_radix_servicenow_proxy.sh

# Example 2: Use the secondary API key from keyvault, using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-2 USE_SECONDARY_API_KEY=true ./update_secret_for_radix_servicenow_proxy.sh)


#######################################################################################
### START
###

echo ""
echo "Updating secret for Radix ServiceNow Proxy"

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR_ RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Optional inputs

USE_SECONDARY_API_KEY=${USE_SECONDARY_API_KEY:=false}
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

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 0
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Functions
###

function updateSecret() {
    SERVICENOW_API_KEY=$(az keyvault secret show -n $KV_SECRET_SERVICENOW_API_KEY --vault-name $AZ_RESOURCE_KEYVAULT | jq -r '.value')
    if [[ -z $SERVICENOW_API_KEY ]]; then
        echo "ERROR: Could not find secret $KV_SECRET_SERVICENOW_API_KEY in keyvault. Quitting.." >&2
        return 1
    fi
    SERVICENOW_CLIENT_SECRET=$(az keyvault secret show -n $KV_SECRET_SERVICENOW_CLIENT_SECRET --vault-name $AZ_RESOURCE_KEYVAULT --query value -otsv)
    if [[ -z $SERVICENOW_CLIENT_SECRET ]]; then
        echo "ERROR: Could not find secret $KV_SECRET_SERVICENOW_CLIENT_SECRET in keyvault. Quitting.." >&2
        return 1
    fi

    echo "PROXY_SERVICENOW_API_KEY=$SERVICENOW_API_KEY
    PROXY_SERVICENOW_CLIENT_SECRET=$SERVICENOW_CLIENT_SECRET
    " > radix-servicenow-proxy-secrets.env

    RADIX_SERVICENOW_PROXY_SECRET_NAME_QA=$(kubectl get secret --namespace "radix-servicenow-proxy-qa" --selector radix-component="api" -ojson | jq -r .items[0].metadata.name)

    if [[ -z "$RADIX_SERVICENOW_PROXY_SECRET_NAME_QA" ]]; then
        echo "ERROR: Could not get secret for api component in radix-vulnerability-scanner-api-qa." >&2
    else
        kubectl create secret generic "$RADIX_SERVICENOW_PROXY_SECRET_NAME_QA" --namespace radix-servicenow-proxy-qa \
            --from-env-file=./radix-servicenow-proxy-secrets.env \
            --dry-run=client -o yaml |
            kubectl apply -f -
    fi

    RADIX_SERVICENOW_PROXY_SECRET_NAME_PROD=$(kubectl get secret --namespace "radix-servicenow-proxy-prod" --selector radix-component="api" -ojson | jq -r .items[0].metadata.name)

    if [[ -z "$RADIX_SERVICENOW_PROXY_SECRET_NAME_PROD" ]]; then
        echo "ERROR: Could not get secret for api component in radix-servicenow-proxy-prod." >&2
    else
        kubectl create secret generic "$RADIX_SERVICENOW_PROXY_SECRET_NAME_PROD" --namespace radix-servicenow-proxy-prod \
            --from-env-file=./radix-servicenow-proxy-secrets.env \
            --dry-run=client -o yaml |
            kubectl apply -f -
    fi

    rm radix-servicenow-proxy-secrets.env

    echo "Restarting radix-servicenow-proxy... "
    kubectl rollout restart deployment -n radix-servicenow-proxy-qa
    kubectl rollout restart deployment -n radix-servicenow-proxy-prod

    echo "Secret updated"
}

### MAIN
updateSecret
