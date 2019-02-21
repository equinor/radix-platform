# Proceedure

## Pushing to ACR for radixdev|radixprod
```
cd radix-platform/charts
tar -zcvf humio-1.0.5.tgz humio
az acr helm push --name radixdev humio-1.0.5.tgz
az acr helm push --name radixprod humio-1.0.5.tgz
```

## Installing to cluster

```
CLUSTER_NAME=stiantest4
ENVIRONMENT=dev

az acr helm repo add --name radixdev && helm repo update
helm upgrade --install humio radixdev/humio --namespace default --version 1.0.0 --set clusterFQDN=$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com --set singleUserPassword=ashdwlneKDSJge4fk
```
