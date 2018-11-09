Tests

Download active test configuration and run locally:

    kubectl get configmap k6scripts -o json | jq -r .data[\"index.js\"] | tee k6script.js
    k6 run - --vus 1 --out influxdb=https://user:pass@radixinfluxdb.azurewebsites.net/influxdb < k6script.js

