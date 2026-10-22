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
# - SLACK_WEBHOOK_URL

#######################################################################################
### Read inputs and configs
###

if [[ -z "$RADIX_ZONE" ]]; then
    echo "ERROR: Please provide RADIX_ZONE" >&2
    exit 1
fi

if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
    echo "ERROR: Please provide Slack Webhook URL ./dailytasks.sh" >&2
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
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault_main <<< "$RADIX_RESOURCE_JSON")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")

#######################################################################################
### Start
###
CLUSTERS=$(az aks list --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --output json | jq '{k8s:[.[] | {name: .name, resourceGroup: .resourceGroup, id: .id}]}')
AZ_RESOURCE_KEYVAULT_ID=$(az keyvault show \
    --name "$AZ_RESOURCE_KEYVAULT" \
    --query id \
    --output tsv \
    --only-show-errors) || {
    echo "ERROR: Could not find resource ID for main Key Vault: $AZ_RESOURCE_KEYVAULT" >&2
    exit 1
}
if [[ -z "$AZ_RESOURCE_KEYVAULT_ID" ]]; then
    echo "ERROR: Azure returned an empty resource ID for main Key Vault: $AZ_RESOURCE_KEYVAULT" >&2
    exit 1
fi
AZ_RESOURCE_KEYVAULT_PUBLIC_ACCESS=$(az keyvault show \
    --name "$AZ_RESOURCE_KEYVAULT" \
    --query properties.publicNetworkAccess \
    --output tsv \
    --only-show-errors) || {
    echo "ERROR: Could not read public network access for main Key Vault: $AZ_RESOURCE_KEYVAULT" >&2
    exit 1
}
if [[ "$AZ_RESOURCE_KEYVAULT_PUBLIC_ACCESS" != "Disabled" ]]; then
    echo "Disabling public access for Key Vault $AZ_RESOURCE_KEYVAULT..."
    az keyvault update \
        --name "$AZ_RESOURCE_KEYVAULT" \
        --public-network-access Disabled \
        --only-show-errors >/dev/null || {
        echo "ERROR: Could not disable public access for main Key Vault: $AZ_RESOURCE_KEYVAULT" >&2
        exit 1
    }
fi

createLock() {
    local NAME=$1
    local TYPE=$2
    local ID=$3

    if az lock create --name "$NAME" --lock-type "$TYPE" --resource "$ID" --output none; then
        if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
            curl -s \
                -X POST \
                -H 'Content-type: application/json' \
                --data '{"text":"GitHub Action: Created '"${NAME}"'"}' "$SLACK_WEBHOOK_URL" >/dev/null
        fi
    else
        echo "ERROR: Could not create lock: $NAME" >&2
        return 1
    fi
}

checkLock() {
    local ID=$1
    local NAME=$2
    local LOCKS lock LOCKTYPE HASDELETELOCK=false

    LOCKS=$(az lock list --resource "$ID") || return 1
    if [[ $(jq 'length' <<< "$LOCKS") -eq 0 ]]; then
        createLock "${NAME}-CanNotDelete-Lock" "CanNotDelete" "$ID"
        return $?
    fi

    while read -r lock; do
        LOCKTYPE=$(jq -r '.level' <<< "$lock")
        if [[ $LOCKTYPE == "CanNotDelete" ]]; then HASDELETELOCK=true; fi
    done <<<"$(jq -c '.[]' <<< "$LOCKS")"

    if [[ $HASDELETELOCK == false ]]; then
        createLock "${NAME}-CanNotDelete-Lock" "CanNotDelete" "$ID"
    fi
}

while read -r CLUSTER; do
    ID=$(jq -n "${CLUSTER}" | jq -r .id)
    CLUSTER_NAME=$(jq -n "${CLUSTER}" | jq -r .name)
    AZ_RESOURCE_GROUP=$(jq -n "${CLUSTER}" | jq -r .resourceGroup)
    echo "Cluster loop"
    echo "ID: $ID"
    echo "CLUSTER_NAME: $CLUSTER_NAME"
    echo "AZ_RESOURCE_GROUP: $AZ_RESOURCE_GROUP"
    echo ""
    VNET_ID=$(az network vnet list \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --query "[?name=='vnet-${CLUSTER_NAME}'].id" \
        --output tsv \
        --only-show-errors)
    checkLock "$ID" "$CLUSTER_NAME"
    checkLock "$VNET_ID" "vnet-$CLUSTER_NAME"
done < <(echo "${CLUSTERS}" | jq -c '.k8s[]')

checkLock "$AZ_RESOURCE_KEYVAULT_ID" "$AZ_RESOURCE_KEYVAULT"
