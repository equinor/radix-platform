# Developing

```
cd radix-platform/charts/radix-stage1
az acr helm repo add --name radixdev && helm repo update
helm dep up
cd ..
tar -zcvf radix-stage1-1.0.28.tgz radix-stage1
az acr helm push --name radixdev radix-stage1-1.0.28.tgz
```

# Gotchas:

For Grafana to get configured with the correct Prometheus Data Source the helm release must be named `radix-stage1`. Update values.yaml if you need to install with another helm release name.

