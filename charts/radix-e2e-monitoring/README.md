

```
cd radix-platform/charts/radix-e2e-monitoring
az acr helm repo add --name radixdev && helm repo update
helm dep up
cd ..
tar -zcvf radix-e2e-monitoring-1.0.0.tgz radix-e2e-monitoring
az acr helm push --name radixdev radix-stage1radix-e2e-monitoring-1.0.0.tgz
```


# Tests

Download active test configuration and run locally:

    kubectl get configmap k6scripts -o json | jq -r .data[\"index.js\"] | tee k6script.js
    k6 run - --vus 1 --out influxdb=https://user:pass@radixinfluxdb.azurewebsites.net/influxdb < k6script.js

