#!/bin/bash
nr_of_replicas=$1
for cluster_entry in `az aks list -ojson | jq -r '.[] | "\(.id)#\(.powerState.code)"' --raw-output`; do
    resource_group=$(echo $cluster_entry | awk -F# '{print $1}' | awk -F/ '{print $5}')
    cluster_name=$(echo $cluster_entry | awk -F# '{print $1}' | awk -F/ '{print $(NF)}')
    subscription_id=$(echo $cluster_entry | awk -F# '{print $1}' | awk -F/ '{print $3'})
    power_state=$(echo $cluster_entry | awk -F# '{print $2}')
    if [[ "$power_state" == "Running" ]]; then
    echo "Cluster $cluster_name is in running state. Scaling radix-cicd-canary..."
    else
    echo "Cluster $cluster_name is not running. skipping..."
    continue
    fi
    az aks get-credentials \
        --name ${cluster_name} \
        --resource-group ${resource_group} \
        --subscription ${subscription_id} \
        --format exec \
        --overwrite-existing
    az aks command invoke \
        --name ${cluster_name} \
        --resource-group ${resource_group} \
        --subscription ${subscription_id} \
        --command "kubectl scale deployment radix-cicd-canary --replicas=${nr_of_replicas} -n radix-cicd-canary"
done