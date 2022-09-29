#!/usr/bin/env bash
#TASK=stop
#TASK=start

if [[ -z "$TASK" ]]; then
    echo "ERROR: Please provide TASK=start|stop ./dailytasks.sh" >&2
    exit 1
fi

function stopcluster() {
    while read -r list; do
        CLUSTER=$(jq -n "${list}" | jq -r .name)
        CGROUP=$(jq -n "${list}" | jq -r .resourceGroup)
        STATUS=$(jq -n "${list}" | jq -r .powerstate)
        if [ "$STATUS" = "Running" ]; then
            if [ "$CLUSTER" = "weekly-38" ]; then
                printf "Stopping cluster $CLUSTER\n"
                az aks stop --name $CLUSTER --resource-group $CGROUP --no-wait
            fi
        fi
    done < <(printf "%s" "${CLUSTERS}" | jq -c '.[].k8s[]')
}

function startcluster() {
    while read -r list; do
        CLUSTER=$(jq -n "${list}" | jq -r .name)
        CGROUP=$(jq -n "${list}" | jq -r .resourceGroup)
        STATUS=$(jq -n "${list}" | jq -r .powerstate)
        if [ "$STATUS" != "Running" ]; then
            printf "Starting cluster $CLUSTER\n"
            az aks start --name $CLUSTER --resource-group $CGROUP --no-wait
        fi
    done < <(printf "%s" "${CLUSTERS}" | jq -c '.[].k8s[]')
}

CLUSTERS=$(az aks list -ojson | jq '[{k8s:[.[] | select(.name | startswith("playground") | not) | {name: .name, resourceGroup: .resourceGroup, powerstate: .powerState.code}]}]')
if [ "$TASK" = "stop" ]; then
    stopcluster
elif [ "$TASK" = "start" ]; then
    startcluster
fi
