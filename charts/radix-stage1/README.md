# Developing

```
cd radix-platform/charts/radix-stage1
az acr helm repo add --name radixdev && helm repo update
rm requirements.lock
helm repo add appscode https://charts.appscode.com/stable/
helm dep up
cd ..
tar -zcvf radix-stage1-1.0.54.tgz radix-stage1
az acr helm push --name radixdev radix-stage1-1.0.54.tgz
```

## Updating radix-stage1-values.yaml:

```
az keyvault secret set \
    --vault-name radix-boot-dev-vault \
    --name radix-stage1-values-dev \
    --file radix-stage1-values-dev.yaml
```


# Installing with values-file from Azure KeyVault

```
az keyvault secret download \
    -f radix-stage1-values-dev.yaml \
    -n radix-stage1-values-dev \
    --vault-name radix-boot-dev-vault

CLUSTER_NAME=stiantest4
ENVIRONMENT=dev

az acr helm repo add --name radixdev && helm repo update

helm upgrade --install radix-stage1 radixdev/radix-stage1 --namespace default --version 1.0.49 -f "radix-stage1-values-$CLUSTER_NAME.$ENVIRONMENT.yaml" \
    --set radix-e2e-monitoring.clusterFQDN=$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.hosts[0]=grafana.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.tls[0].hosts[0]=grafana.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set grafana.env.GF_SERVER_ROOT_URL=https://grafana.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.hosts[0]=prometheus.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.tls[0].hosts[0]=prometheus.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set kubed.config.clusterName=$CLUSTER_NAME \
    --set externalDns.clusterName=$CLUSTER_NAME \
    --set externalDns.environment=$ENVIRONMENT \
    --set clusterWildcardCert.clusterName=$CLUSTER_NAME \
    --set clusterWildcardCert.environment=$ENVIRONMENT \
    --set radix-kubernetes-api-proxy.clusterFQDN=$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set humio.clusterFQDN=$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set humio.enabled=true

rm radix-stage1-values-dev.yaml
```

# OUTDATED METHOD: Installing with values from Azure KeyVault

```
az keyvault secret download \
    -f radix-credentials.json \
    -n credentials \
    --vault-name radix-boot-dev-vault

CLUSTER_NAME=dev2
ENVIRONMENT=dev

az acr helm repo add --name radixdev && helm repo update

helm upgrade --install radix-stage1 radixdev/radix-stage1 --namespace default --version 1.0.37 \
    --set radix-e2e-monitoring.clusterFQDN=$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set radix-e2e-monitoring.influxDBurl=https://`cat radix-credentials.json | jq -r .influxDBUsername`:`cat radix-credentials.json | jq -r .influxDBPassword`@radixinfluxdb.azurewebsites.net/influxdb \
    --set imageCredentials.registry=radixdev.azurecr.io \
    --set imageCredentials.username=radixdev \
    --set imageCredentials.password="`cat radix-credentials.json | jq -r .containerRegistryPassword`" \
    --set grafana.ingress.hosts[0]=grafana.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.tls[0].hosts[0]=grafana.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set grafana.env.GF_SERVER_ROOT_URL=https://grafana.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set grafana.adminUser="`cat radix-credentials.json | jq -r .grafanaAdminUser`" \
    --set grafana.adminPassword="`cat radix-credentials.json | jq -r .grafanaAdminPassword`" \
    --set kube-prometheus.prometheus.ingress.hosts[0]=prometheus.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.tls[0].hosts[0]=prometheus.$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set kube-prometheus.prometheus.remoteWrite[0].url="https://`cat radix-credentials.json | jq -r .influxDBUsername`:`cat radix-credentials.json | jq -r .influxDBPassword`@radixinfluxdb.azurewebsites.net/api/v1/prom/write?db=influxdb" \
    --set kubed.config.clusterName=$CLUSTER_NAME \
    --set externalDns.clusterName=$CLUSTER_NAME \
    --set externalDns.environment=$ENVIRONMENT \
    --set clusterWildcardCert.clusterName=$CLUSTER_NAME \
    --set clusterWildcardCert.environment=$ENVIRONMENT \
    --set radix-kubernetes-api-proxy.clusterFQDN=$CLUSTER_NAME.$ENVIRONMENT.radix.equinor.com \
    --set certManagerAzureDnsSecret="`cat radix-credentials.json | jq -r .certManagerAzureDnsSecret`"

rm radix-credentials.json
```

# Gotchas:

For Grafana to get configured with the correct Prometheus Data Source the helm release must be named `radix-stage1`. Update values.yaml if you need to install with another helm release name.

If you install and forget to update CLUSTER_NAME you might create a race condition where the two clusters fight over 