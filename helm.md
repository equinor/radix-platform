# radix-platform helm chart

## Usage

This is about using the chart

### Preparation

Start by setting some variables that will be used later

    export RADIX_TLD=radix.equinor.com
    export RADIX_ENV=dev
    export RADIX_CLUSTER_NAME=playground-helm-charts-sov-o
    export RADIX_CLUSTER_DNS_SUFFIX=$RADIX_CLUSTER_NAME.$RADIX_ENV.$RADIX_TLD
    export RADIX_AKS_API_SERVER=playground-playground-helm--16ede4-8a01e6f7.hcp.northeurope.azmk8s.io

### Installing or upgrading

Install the `radix-platform` helm chart:

```sh
helm upgrade radix-platform --version 1.0.7 radixdev/radix-platform \
    --set testing.clusterFQDN=$RADIX_CLUSTER_DNS_SUFFIX \
    --set testing.influxDBurl=http://influxwrite:x@radixinfluxdb.azurewebsites.net/influxdb \
    --set imageCredentials.registry=radixdev.azurecr.io \
    --set imageCredentials.username=radixdev \
    --set imageCredentials.password=x \
    --set grafana.ingress.hosts[0]=grafana.$RADIX_CLUSTER_DNS_SUFFIX \
    --set grafana.ingress.tls[0].hosts[0]=grafana.$RADIX_CLUSTER_DNS_SUFFIX \
    --set grafana.env.GF_SERVER_ROOT_URL=https://grafana.$RADIX_CLUSTER_DNS_SUFFIX \
    --set grafana.adminUser=radixadmin \
    --set grafana.adminPassword=x \
    --set kube-prometheus.prometheus.ingress.hosts[0]=prometheus.$RADIX_CLUSTER_DNS_SUFFIX \
    --set kube-prometheus.prometheus.ingress.tls[0].hosts[0]=prometheus.$RADIX_CLUSTER_DNS_SUFFIX \
    --set kube-prometheus.prometheus.remoteWrite[0].url=https://influxwrite:x@radixinfluxdb.azurewebsites.net/api/v1/prom/write?db=influxdb \
    --set kubed.config.clusterName=$RADIX_CLUSTER_NAME \
    --set externalDns.deploymentTargetName=$RADIX_CLUSTER_NAME \
    --set externalDns.environment=$RADIX_ENV \
    --set clusterWildcardCert.deploymentTargetName=$RADIX_CLUSTER_NAME \
    --set clusterWildcardCert.environment=$RADIX_ENV \
    --set radix-kubernetes-api-proxy.clusterFQDN=$RADIX_CLUSTER_DNS_SUFFIX \
    --set radix-operator.clustername=$RADIX_CLUSTER_NAME \
    --set radix-operator.clusterAKSAPIserver=$RADIX_AKS_API_SERVER \
    --set radix-operator.imageCredentials.username=radixdev \
    --set radix-operator.imageCredentials.password='x'
```

These fields need to be filled in manually with usernames and passwords:
  - `testing.influxDBurl`
  - `imageCredentials.password`
  - `grafana.adminPassword`
  - `kube-prometheus.prometheus.remoteWrite[0].url`
  - `radix-operator.imageCredentials.password`


### Deleting

To delete everything installed by the `radix-platform` helm chart, do this:

```sh
helm delete --purge radix-platform
kubectl delete psp radix-platform-grafana
kubectl delete crd certificates.certmanager.k8s.io
kubectl delete crd clusterissuers.certmanager.k8s.io
kubectl delete crd issuers.certmanager.k8s.io
kubectl delete job radix-platform-prometheus-operator-create-sm-job
kubectl delete job radix-platform-prometheus-operator-get-crd
```

## Chart development

This is about developing the chart

## Update chart in repo

 - Bump version number in Chart.yaml

```sh
cd charts
tar -zcvf radix-platform-1.0.7.tgz radix-platform
az acr helm push --name radixdev radix-platform-1.0.7.tgz
```

**PS** Version number in `Chart.yaml` **MUST** match version number used in `.tgz` file for `az acr helm push` to succeed.

## Todo / known problems

 - prometheus-operator needs to be installed first separately to create CRDs
 - kubelet-service-monitor-patch needs to be applied after kube-prometheus has installed all the ServiceMonitors
 - `--set grafana.adminPassword` does not get applied!