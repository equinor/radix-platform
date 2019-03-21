# Installation on cluster

`install_base_components.sh` script automatically installs e2e monitoring running inside a cluster monitoring itself.

# Installation on other cluster

Update env var to cluster name and execute commands. 

** PS: If the cluster already has installed another e2e helm chart, add the setting `--set createServiceAccountAndRoles=false` to the helm command! **

az keyvault secret download \
    --vault-name radix-vault-prod \
    --name radix-e2e-monitoring \
    --file radix-e2e-monitoring.yaml

export CLUSTER_FQDN=playground-4.playground.radix.equinor.com

helm upgrade --install e2e-$CLUSTER_FQDN \
    radixprod/radix-e2e-monitoring \
    --set clusterFQDN=$CLUSTER_FQDN \
    -f radix-e2e-monitoring.yaml \
    --set createServiceAccountAndRoles=false

rm -f radix-e2e-monitoring.yaml


# Upload new version to Helm Registry
```
cd radix-platform/charts/radix-e2e-monitoring
az account set --subscription "Omnia Radix Development"
az acr helm repo add --name radixdev && helm repo update
helm dep up
cd ..
tar -zcvf radix-e2e-monitoring-1.0.12.tgz radix-e2e-monitoring
az acr helm push --name radixdev radix-e2e-monitoring-1.0.12.tgz

az account set --subscription "Omnia Radix Production"
az acr helm repo add --name radixprod && helm repo update
az acr helm push --name radixprod radix-e2e-monitoring-1.0.12.tgz

az acr helm repo add --name radixprod && helm repo update
```


# Developing and debugging

Download active test configuration and run locally:

    az account get-access-token | jq -r .accessToken > tokenFile
    kubectl get configmap radix-e2e-monitoring-$CLUSTER_NAME-k6scripts -o json | jq -r .data[\"index.js\"] | tee k6script.js
    TOKEN_FILE_PATH="/mnt/c/Data-Disk-Enc/go/src/github.com/equinor/tokenFile" k6 run - --vus 1 --out influxdb=https://user:pass@radixinfluxdb.azurewebsites.net/influxdb --tag cluster=$CLUSTER_FQDN < k6script.js

    rm tokenFile