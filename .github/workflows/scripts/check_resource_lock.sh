#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create resource lock if missing

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE=prod|c2

#######################################################################################
### Read inputs and configs
###

if [[ -z "$RADIX_ZONE" ]]; then
    echo "ERROR: Please provide RADIX_ZONE" >&2
    exit 1
fi

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh


#######################################################################################
### Environment
###
printf "\n%s► Read YAML configfile $RADIX_ZONE"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "\n%s► Read terraform variables and configuration"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")

#######################################################################################
### Start
###

SLACK_WEBHOOK_URL="$(az keyvault secret show \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" \
    --name "slack-webhook" \
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

    VNET_ID=$(az network vnet list \
        --resource-group "${AZ_RESOURCE_GROUP}" \
        --query "[?name=='vnet-${CLUSTER}'].id" \
        --output tsv \
        --only-show-errors)

    function checkLock() {
        ID=$1
        NAME=$2

        LOCKS=$(az lock list --resource "$ID")
        if [[ $LOCKS == "[]" ]]; then
            createLock "${NAME}-CanNotDelete-Lock" "CanNotDelete" "${ID}"
            # createLock "${NAME}-ReadOnly-Lock" "ReadOnly" "${ID}"
        else
            HASDELETELOCK=false
            HASREADONLYLOCK=false
            while read -r lock; do
                LOCKTYPE=$(jq -n "${lock}" | jq -r .level)
                if [[ $LOCKTYPE == "CanNotDelete" ]]; then HASDELETELOCK=true; fi
                # if [[ $LOCKTYPE == "ReadOnly" ]]; then HASREADONLYLOCK=true; fi
            done <<<"$(az lock list --resource "$ID" | jq -c '.[]')"

            if [[ $HASDELETELOCK == false ]]; then createLock "${NAME}-CanNotDelete-Lock" "CanNotDelete" "${ID}"; fi
            # if [[ $HASREADONLYLOCK == false ]]; then createLock "${NAME}-ReadOnly-Lock" "ReadOnly" "${ID}"; fi
        fi
    }

    checkLock "$ID" "$CLUSTER_NAME"
    checkLock "$VNET_ID" "$VNET_NAME"

done < <(echo "${CLUSTERS}" | jq -c '.k8s[]')
