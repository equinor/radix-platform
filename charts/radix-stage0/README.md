# Developing

```
cd radix-platform/charts/radix-stage0
az acr helm repo add --name radixdev && helm repo update
rm requirements.lock
helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/
helm dep up
cd ..
tar -zcvf radix-stage0-1.0.4.tgz radix-stage0
az acr helm push --name radixdev radix-stage0-1.0.4.tgz
```

# Installing

```
az acr helm repo add --name radixdev && helm repo update
helm upgrade --install radix-stage0 radixdev/radix-stage0 --namespace default --version 1.0.3
```
