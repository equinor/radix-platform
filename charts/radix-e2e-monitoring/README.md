

```
cd radix-platform/charts/radix-e2e-monitoring
az account set --subscription "Omnia Radix Development"
az acr helm repo add --name radixdev && helm repo update
helm dep up
cd ..
tar -zcvf radix-e2e-monitoring-1.0.5.tgz radix-e2e-monitoring
az acr helm push --name radixdev radix-e2e-monitoring-1.0.5.tgz

az account set --subscription "Omnia Radix Production"
az acr helm repo add --name radixprod && helm repo update
az acr helm push --name radixprod radix-e2e-monitoring-1.0.5.tgz
```


# Tests

Download active test configuration and run locally:

    az account get-access-token | jq -r .accessToken > tokenFile
    kubectl get configmap k6scripts -o json | jq -r .data[\"index.js\"] | tee k6script.js
    TOKEN_FILE_PATH="/mnt/c/Data-Disk-Enc/go/src/github.com/statoil/tokenFile" k6 run - --vus 1 --out influxdb=https://user:pass@radixinfluxdb.azurewebsites.net/influxdb < k6script.js

    rm tokenFile