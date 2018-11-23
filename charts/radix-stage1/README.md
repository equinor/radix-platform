# Developing

```
cd radix-platform/charts/radix-stage1
az acr helm repo add --name radixdev && helm repo update
helm dep up
cd ..
tar -zcvf radix-stage1-1.0.17.tgz radix-stage1
az acr helm push --name radixdev radix-stage1-1.0.17.tgz
```


# Tests

Download active test configuration and run locally:

    kubectl get configmap k6scripts -o json | jq -r .data[\"index.js\"] | tee k6script.js
    k6 run - --vus 1 --out influxdb=https://user:pass@radixinfluxdb.azurewebsites.net/influxdb < k6script.js

# Gotchas:

For Grafana to get configured with the correct Prometheus Data Source the helm release must be named `radix-stage1`. Update values.yaml if you need to install with another helm release name.