#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create resource lock if missing

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

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

#######################################################################################
### Start
###

SLACK_WEBHOOK_URL="$(az keyvault secret show \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" \
    --name "${KV_SECRET_SLACK_WEBHOOK}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" |
    jq -r .value)"
CLUSTERS=$(az aks list --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --output json | jq '{k8s:[.[] | {name: .name, resourceGroup: .resourceGroup, id: .id}]}')

createLock() {
    local NAME=$1
    local TYPE=$2
    local ID=$3

    if az lock create --name "${NAME}" --lock-type "${TYPE}" --resource "${ID}"; then
        curl -s \
            -X POST \
            -H 'Content-type: application/json' \
            --data '{"text":"GitHub Action: Created '"${NAME}"'"}' "${SLACK_WEBHOOK_URL}" >/dev/null
    else
        echo "ERROR: Could not create lock: ${NAME}"
    fi

}

while read -r CLUSTER; do
    ID=$(jq -n "${CLUSTER}" | jq -r .id)
    CLUSTER_NAME=$(jq -n "${CLUSTER}" | jq -r .name)
    AZ_RESOURCE_GROUP=$(jq -n "${CLUSTER}" | jq -r .resourceGroup)

    # Import networking variables for AKS
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/aks/network.env"

    VNET_ID=$(az network vnet list \
        --resource-group "${AZ_RESOURCE_GROUP}" \
        --query "[?name=='${VNET_NAME}'].id" \
        --output tsv \
        --only-show-errors)

    function checkLock() {
        ID=$1
        NAME=$2

        LOCKS=$(az lock list --resource "$ID")
        if [[ $LOCKS == "[]" ]]; then
            createLock "${NAME}-CanNotDelete-Lock" "CanNotDelete" "${ID}"
            createLock "${NAME}-ReadOnly-Lock" "ReadOnly" "${ID}"
        else
            HASDELETELOCK=false
            HASREADONLYLOCK=false
            while read -r lock; do
                LOCKTYPE=$(jq -n "${lock}" | jq -r .level)
                if [[ $LOCKTYPE == "CanNotDelete" ]]; then HASDELETELOCK=true; fi
                if [[ $LOCKTYPE == "ReadOnly" ]]; then HASREADONLYLOCK=true; fi
            done <<<"$(az lock list --resource "$ID" | jq -c '.[]')"

            if [[ $HASDELETELOCK == false ]]; then createLock "${NAME}-CanNotDelete-Lock" "CanNotDelete" "${ID}"; fi
            if [[ $HASREADONLYLOCK == false ]]; then createLock "${NAME}-ReadOnly-Lock" "ReadOnly" "${ID}"; fi
        fi
    }

    checkLock "$ID" "$CLUSTER_NAME"
    checkLock "$VNET_ID" "$VNET_NAME"

done < <(echo "${CLUSTERS}" | jq -c '.k8s[]')
