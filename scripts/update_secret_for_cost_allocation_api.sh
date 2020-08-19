#!/bin/bash

# PURPOSE
# Configures the secrets for radix cost allocation API on the cluster given the context.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env ./update_secret_for_cost_allocation_api.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env ./update_secret_for_cost_allocation_api.sh)
#

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)

echo ""
echo "Updating secret for the radix cost allocation API"

# Validate mandatory input

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

function updateSecret() {
    echo "SQL_SERVER=$(az keyvault secret show -n radix-cost-allocation-api-secrets --vault-name "$AZ_RESOURCE_KEYVAULT"|jq -r '.value'| jq -r '.db.server')
    SQL_DATABASE=$(az keyvault secret show -n radix-cost-allocation-api-secrets --vault-name "$AZ_RESOURCE_KEYVAULT"|jq -r '.value'| jq -r '.db.database')
    SQL_USER=$(az keyvault secret show -n radix-cost-allocation-api-secrets --vault-name "$AZ_RESOURCE_KEYVAULT"|jq -r '.value'| jq -r '.db.user')
    SQL_PASSWORD=$(az keyvault secret show -n radix-cost-allocation-api-secrets --vault-name "$AZ_RESOURCE_KEYVAULT"|jq -r '.value'| jq -r '.db.password')
    SUBSCRIPTION_COST_VALUE=$(az keyvault secret show -n radix-cost-allocation-api-secrets --vault-name "$AZ_RESOURCE_KEYVAULT"|jq -r '.value'| jq -r '.subscriptionCost.value')
    SUBSCRIPTION_COST_CURRENCY=$(az keyvault secret show -n radix-cost-allocation-api-secrets --vault-name "$AZ_RESOURCE_KEYVAULT"|jq -r '.value'| jq -r '.subscriptionCost.currency')
    " > radix-cost-allocation-api-secrets.yaml
    
    COST_ALLOCATION_API_SECRET_NAME_QA=$(kubectl get secret -l radix-component="server" -n "radix-cost-allocation-api-qa" -o=jsonpath=‘{.items[0].metadata.name}’ | sed 's/‘/ /g;s/’/ /g' | tr -d '[:space:]')

    if [[ -z "$COST_ALLOCATION_API_SECRET_NAME_QA" ]]; then
        echo "Please provide COST_ALLOCATION_API_SECRET_NAME_QA."
    else
        kubectl create secret generic "$COST_ALLOCATION_API_SECRET_NAME_QA" --namespace radix-cost-allocation-api-qa \
            --from-env-file=./radix-cost-allocation-api-secrets.yaml \
            --dry-run=client -o yaml |
            kubectl apply -f -
    fi

    COST_ALLOCATION_API_SECRET_NAME_PROD=$(kubectl get secret -l radix-component="server" -n "radix-cost-allocation-api-prod" -o=jsonpath=‘{.items[0].metadata.name}’ | sed 's/‘/ /g;s/’/ /g' | tr -d '[:space:]')

    if [[ -z "$COST_ALLOCATION_API_SECRET_NAME_PROD" ]]; then
        echo "Please provide COST_ALLOCATION_API_SECRET_NAME_PROD."
    else
        kubectl create secret generic "$COST_ALLOCATION_API_SECRET_NAME_PROD" --namespace radix-cost-allocation-api-prod \
            --from-env-file=./radix-cost-allocation-api-secrets.yaml \
            --dry-run=client -o yaml |
            kubectl apply -f -
    fi

    rm radix-cost-allocation-api-secrets.yaml

    echo "Secret updated"
}

### MAIN
updateSecret
