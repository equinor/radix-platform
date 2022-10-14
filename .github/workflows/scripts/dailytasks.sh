#!/usr/bin/env bash
#TASK=stop
#TASK=start

if [[ -z "$TASK" ]]; then
    echo "ERROR: Please provide TASK=start|stop ./dailytasks.sh" >&2
    exit 1
fi

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

function stopcluster() {
    while read -r list; do
        CLUSTER=$(jq -n "${list}" | jq -r .name)
        CGROUP=$(jq -n "${list}" | jq -r .resourceGroup)
        STATUS=$(jq -n "${list}" | jq -r .powerstate)
        if [ "$STATUS" = "Running" ]; then
            printf "Stopping cluster $CLUSTER\n"
            az aks stop --name $CLUSTER --resource-group $CGROUP --no-wait
            curl -s -X POST -H 'Content-type: application/json' --data '{"text":"GitHub Action: Stopping cluster '"$CLUSTER"'"}' "$SLACK_WEBHOOK_URL" > /dev/null
        fi
    done < <(printf "%s" "${CLUSTERS}" | jq -c '.[].k8s[]')
}

function startcluster() {
    while read -r list; do
        CLUSTER=$(jq -n "${list}" | jq -r .name)
        CGROUP=$(jq -n "${list}" | jq -r .resourceGroup)
        STATUS=$(jq -n "${list}" | jq -r .powerstate)
        SCHEDULE=$(jq -n "${list}" | jq -r .autostartupschedule)
        if [[ "$STATUS" != "Running" && "$SCHEDULE" = "true" ]]; then
            printf "Starting cluster $CLUSTER\n"
            az aks start --name $CLUSTER --resource-group $CGROUP --no-wait
            curl -s -X POST -H 'Content-type: application/json' --data '{"text":"GitHub Action: Starting cluster '"$CLUSTER"'"}' "$SLACK_WEBHOOK_URL" > /dev/null
        fi
    done < <(printf "%s" "${CLUSTERS}" | jq -c '.[].k8s[]')
}



CLUSTERS=$(az aks list -ojson | jq '[{k8s:[.[] | select(.name | startswith("playground") | not) | {name: .name, resourceGroup: .resourceGroup, powerstate: .powerState.code, autostartupschedule: .tags.autostartupschedule}]}]')
SLACK_WEBHOOK_URL="$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name "$KV_SECRET_SLACK_WEBHOOK" | jq -r .value)"
echo -e "   ------------------------------------------------------------------"
printf '%s %s\n' "   -  DATE                             : $(date)"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  ACTION                           : $TASK"
echo -e "   -------------------------------------------------------------------"


if [ "$TASK" = "stop" ]; then
    stopcluster
elif [ "$TASK" = "start" ]; then
    startcluster
fi
