#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Starting/stopping clusters in subscription

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - TASK                : Ex: "start", "stop"

#######################################################################################
### Read inputs and configs
###

if [[ -z "$RADIX_ZONE" ]]; then
    echo "ERROR: Please provide RADIX_ZONE" >&2
    exit 1
fi

if [[ -z "$TASK" ]]; then
    echo "ERROR: Please provide TASK=start|stop ./dailytasks.sh" >&2
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
RADIX_ZONE=$(yq '.radix_environment' <<< "$RADIX_ZONE_YAML")
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")

#######################################################################################
### Start
###

function stopcluster() {
    while read -r list; do
        CLUSTER_NAME=$(jq -n "${list}" | jq -r .name)
        RESOURCE_GROUP=$(jq -n "${list}" | jq -r .resourceGroup)
        POWER_STATE=$(jq -n "${list}" | jq -r .powerstate)

        if [ "$POWER_STATE" = "Running" ]; then
            printf "Stopping cluster %s\n" "${CLUSTER_NAME}"

            az aks stop --name "${CLUSTER_NAME}" \
                --resource-group "${RESOURCE_GROUP}" \
                --subscription "${DEV_SUBSCRIPTION}" \
                --no-wait

            curl -s \
                -X POST \
                -H 'Content-type: application/json' \
                --data '{"text":"GitHub Action: Stopping cluster '"${CLUSTER_NAME}"'"}' "${SLACK_WEBHOOK_URL}" >/dev/null
        fi
    done < <(printf "%s" "${CLUSTERS}" | jq -c '.[].k8s[]')
}

function startcluster() {
    while read -r list; do
        CLUSTER_NAME=$(jq -n "${list}" | jq -r .name)
        RESOURCE_GROUP=$(jq -n "${list}" | jq -r .resourceGroup)
        POWER_STATE=$(jq -n "${list}" | jq -r .powerstate)
        AUTOSTARTUP=$(jq -n "${list}" | jq -r .autostartupschedule)

        if [[ "$POWER_STATE" != "Running" && "$AUTOSTARTUP" = "true" ]]; then
            printf "Starting cluster %s\n" "${CLUSTER_NAME}"

            az aks start --name "${CLUSTER_NAME}" \
                --resource-group "${RESOURCE_GROUP}" \
                --subscription "${DEV_SUBSCRIPTION}" \
                --no-wait

            curl -s \
                -X POST \
                -H 'Content-type: application/json' \
                --data '{"text":"GitHub Action: Starting cluster '"${CLUSTER_NAME}"'"}' "${SLACK_WEBHOOK_URL}" >/dev/null
        fi
    done < <(printf "%s" "${CLUSTERS}" | jq -c '.[].k8s[]')
}

DEV_SUBSCRIPTION="16ede44b-1f74-40a5-b428-46cca9a5741b"
CLUSTERS=$(az aks list --subscription "${DEV_SUBSCRIPTION}" \
    --output json |
    jq '[{k8s:[.[] | select(.name | startswith("playground") | not) | {name: .name, resourceGroup: .resourceGroup, powerstate: .powerState.code, autostartupschedule: .tags.autostartupschedule}]}]')

echo -e ""
echo -e "Dailytask will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  ACTION                           : ${TASK}"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name --output tsv)"
echo -e ""

echo ""

if [ "${TASK}" = "stop" ]; then
    stopcluster
elif [ "${TASK}" = "start" ]; then
    startcluster
fi
