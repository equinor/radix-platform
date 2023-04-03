#!/usr/bin/env bash

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
### Resolve dependencies on other scripts
###

MOVE_CUSTOM_INGRESSES_SCRIPT="scripts/move_custom_ingresses.sh"
if ! [[ -x "$MOVE_CUSTOM_INGRESSES_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The move custom ingresses script is not found or it is not executable in path $MOVE_CUSTOM_INGRESSES_SCRIPT" >&2
fi

#######################################################################################
### Start
###

KV_SECRET_ACTIVE_CLUSTER="radix-flux-active-cluster-${RADIX_ZONE}"

SOURCE_CLUSTER="$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name "$KV_SECRET_ACTIVE_CLUSTER" | jq -r .value)"

function updateClusterIps() {
    local CLUSTER_NAMES
    local NEW_IP
    local ACTION

    CLUSTER_NAMES=$1
    NEW_IP=$2
    ACTION=$3

    for CLUSTER_NAME in ${CLUSTER_NAMES}; do
        if [[ -n ${CLUSTER_NAME} ]]; then
            # Check if cluster exists
            printf "\nUpdate cluster \"%s\".\n" "${CLUSTER_NAME}"
            if [[ -n "$(az aks list --query "[?name=='${CLUSTER_NAME}'].name" --subscription "${AZ_SUBSCRIPTION_ID}" -otsv)" ]]; then
                ip_whitelist=$(az aks show --name "${CLUSTER_NAME}" --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --query apiServerAccessProfile.authorizedIpRanges)

                if [[ $ACTION == "add" ]]; then
                    k8s_api_ip_whitelist=$(jq <<<"$ip_whitelist" | jq --arg NEW_IP "${NEW_IP}/32" '. += [$NEW_IP]' | jq -r '. | join(",")')
                elif [[ $ACTION == "delete" ]]; then
                    k8s_api_ip_whitelist=$(jq <<<"$ip_whitelist" | jq --arg NEW_IP "${NEW_IP}/32" "del(.[] | select(. == \"$NEW_IP\"))" | jq -r '. | join(",")')
                fi

                if [[ -n $k8s_api_ip_whitelist ]]; then
                    printf "\nUpdating cluster with whitelist IPs...\n"
                    if [[ $(az aks update --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --name "${CLUSTER_NAME}" --api-server-authorized-ip-ranges "${k8s_api_ip_whitelist}") == *"ERROR"* ]]; then
                        printf "ERROR: Could not update cluster. Quitting...\n" >&2
                        exit 1
                    fi
                    printf "\nDone.\n"
                fi
            else
                printf "\nERROR: Could not find the cluster. Make sure you have access to it." >&2
                exit 1
            fi
        fi
    done
}

echo "AZ_RESOURCE_KEYVAULT: $AZ_RESOURCE_KEYVAULT"
echo "DEST_CLUSTER: $DEST_CLUSTER"
echo "SOURCE_CLUSTER: $SOURCE_CLUSTER"

if [[ "${SOURCE_CLUSTER}" != "${DEST_CLUSTER}" ]]; then

    updateClusterIps "${SOURCE_CLUSTER} ${DEST_CLUSTER}" "${GITHUB_PUBLIC_IP}" "add"

    if [[ -n $SOURCE_CLUSTER ]]; then
        echo "run move_custom_ingresses.sh"
        (RADIX_ZONE_ENV=scripts/radix-zone/radix_zone_dev.env SOURCE_CLUSTER="${SOURCE_CLUSTER}" DEST_CLUSTER="${DEST_CLUSTER}" USER_PROMPT="false" source "${MOVE_CUSTOM_INGRESSES_SCRIPT}")
        wait # wait for subshell to finish
    else
        echo "run move_custom_ingresses.sh"
        (RADIX_ZONE_ENV=scripts/radix-zone/radix_zone_dev.env DEST_CLUSTER="${DEST_CLUSTER}" USER_PROMPT="false" source "${MOVE_CUSTOM_INGRESSES_SCRIPT}")
        wait # wait for subshell to finish
    fi

    az keyvault secret set \
        --vault-name "${AZ_RESOURCE_KEYVAULT}" \
        --name "${KV_SECRET_ACTIVE_CLUSTER}" \
        --value "${DEST_CLUSTER}"

    updateClusterIps "${SOURCE_CLUSTER} ${DEST_CLUSTER}" "${GITHUB_PUBLIC_IP}" "delete"
fi
