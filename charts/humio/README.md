# Proceedure

## Pushing to ACR for radixdev|radixprod
```
cd radix-platform/charts/humio
az acr helm repo add --name radixdev
az acr helm repo add --name radixprod
helm repo update
helm dep up
cd ..
tar -zcvf humio-1.0.2.tgz humio
az acr helm push --name radixdev humio-1.0.2.tgz
az acr helm push --name radixprod humio-1.0.2.tgz
```

## Installing to cluster

```
CLUSTER_NAME=stiantest4
ENVIRONMENT=dev

az acr helm repo add --name radixdev && helm repo update
helm upgrade --install humio radixdev/humio --namespace default --version 1.0.0 --set clusterFQDN=$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com --set singleUserPassword=ashdwlneKDSJge4fk
```
