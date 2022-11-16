#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Configures the secrets for radix cost allocation API on the cluster given the context.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-2 ./update_secret_for_cost_allocation_api.sh

# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-2 ./update_secret_for_cost_allocation_api.sh)

#######################################################################################
### START
###

echo ""
echo "Updating secret for the radix cost allocation API"

# Validate mandatory input

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

function updateSecret() {
    whitelist='{"whiteList":[]}'
    for appName in ${COST_ALLOCATION_APP_WHITELIST[@]}; do
        whitelist=$(echo $whitelist | jq -c --arg appName "$appName" '.whiteList[.whiteList | length] = $appName ')
    done

    readers='{"groups":[]}'
    for group in ${COST_ALLOCATION_REPORT_READER_AD_GROUPS[@]}; do
        readers=$(echo $readers | jq -c --arg group "$group" '.groups[.groups | length] = $group ')
    done

    COST_ALLOCATION_SQL_API_PASSWORD=$(az keyvault secret show -n $KV_SECRET_COST_ALLOCATION_DB_API --vault-name $AZ_RESOURCE_KEYVAULT | jq -r '.value')
    if [[ -z $COST_ALLOCATION_SQL_API_PASSWORD ]]; then
        echo "ERROR: Could not find secret $KV_SECRET_COST_ALLOCATION_DB_API in keyvault. Quitting.." >&2
        return 1
    fi

    echo "SQL_SERVER=$COST_ALLOCATION_SQL_SERVER_FQDN
    SQL_DATABASE=$COST_ALLOCATION_SQL_DATABASE_NAME
    SQL_USER=$COST_ALLOCATION_SQL_API_USER
    SQL_PASSWORD=$COST_ALLOCATION_SQL_API_PASSWORD
    SUBSCRIPTION_COST_VALUE=0
    SUBSCRIPTION_COST_CURRENCY=NOK
    WHITELIST=$whitelist
    AD_REPORT_READERS=$readers
    TOKEN_ISSUER=https://sts.windows.net/$(az account show --query tenantId -otsv)/
    " > radix-cost-allocation-api-secrets.env

    COST_ALLOCATION_API_SECRET_NAME_QA=$(kubectl get secret --namespace "radix-cost-allocation-api-qa" --selector radix-component="server" -ojson | jq -r .items[0].metadata.name)

    if [[ -z "$COST_ALLOCATION_API_SECRET_NAME_QA" ]]; then
        echo "ERROR: Could not get secret for server component in radix-cost-allocation-api-qa." >&2
    else
        kubectl create secret generic "$COST_ALLOCATION_API_SECRET_NAME_QA" --namespace radix-cost-allocation-api-qa \
            --from-env-file=./radix-cost-allocation-api-secrets.env \
            --dry-run=client -o yaml |
            kubectl apply -f -
    fi

    COST_ALLOCATION_API_SECRET_NAME_PROD=$(kubectl get secret --namespace "radix-cost-allocation-api-prod" --selector radix-component="server" -ojson | jq -r .items[0].metadata.name)

    if [[ -z "$COST_ALLOCATION_API_SECRET_NAME_PROD" ]]; then
        echo "ERROR: Could not get secret for server component in radix-cost-allocation-api-qa." >&2
    else
        kubectl create secret generic "$COST_ALLOCATION_API_SECRET_NAME_PROD" --namespace radix-cost-allocation-api-prod \
            --from-env-file=./radix-cost-allocation-api-secrets.env \
            --dry-run=client -o yaml |
            kubectl apply -f -
    fi

    rm radix-cost-allocation-api-secrets.env

    echo "Restarting radix-cost-allocation-api... "
    kubectl rollout restart deployment -n radix-cost-allocation-api-qa
    kubectl rollout restart deployment -n radix-cost-allocation-api-prod
    
    echo "Secret updated"
}

### MAIN
updateSecret
