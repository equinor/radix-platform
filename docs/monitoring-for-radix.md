# Radix Monitoring

## For Radix platform users

[Work in progress](monitoring-for-users.md)

## For Radix platform developers

Monitoring follows the default Kubernetes monitoring stack:

  * Frontend, visualization - [Grafana](https://grafana.com/)
  * Backend, storage, scraping - [Prometheus](https://prometheus.io)
  * Data exporters - kube-state-metrics (exposes Kubernetes metrics), node-exporter (exposes Linux worker node metrics)
  * Helpers - Prometheus operator, Alertmanager, Push-gateway

### Deployment methods

There are two ways of deploying Prometheus and the related components. 

#### Non-Kubernetes specific

The first is as a regular Kubernetes deployment with .yaml files specifying replicas and services. There is an official Helm package that installs all the components necessary (Prometheus, Alertmanager, kube-state-metrics, node-exporter and push-gateway):

    helm install stable/prometheus 

Docs: https://github.com/kubernetes/charts/tree/master/stable/prometheus

Prometheus has a plugin to do service-discovery on Kubernetes resources configured via prometheus.yml.

### Prometheus Operator

The other way is via the Operator Pattern where a few new resource types are added to Kubernetes and program called Prometheus Operator watches Kubernetes resources and makes sure Prometheus is deployed according to spec and that Prometheus is monitoring the correct targets (aia ServiceMonitor configuration object).

Since this is considered more Kubernetes-native and allows applications themselves greater control on how they want to be monitored we will opt for this deployment method for now. The community around Prometheus Operator seems alive and healthy, even though there is a Red Flag since https://github.com/coreos/prometheus-operator/blob/master/ROADMAP.md has not been updated since february 2017.

The CoreOS Prometheus Operator also has 3 different installation methods.
  * kubectl: kubectl apply -f https://github.com/coreos/prometheus-operator/blob/master/bundle.yaml
  * jsonnet/ksonnet: https://github.com/coreos/prometheus-operator/tree/master/contrib/kube-prometheus
  * Helm: https://github.com/coreos/prometheus-operator/tree/master/helm

Helm seems easier and more standardized than jsonnet/ksonnet so we will use Helm for deploying.

## Installation

Install Helm if necessary:

    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
    helm init

Add CoreOS Helm Repo:

    helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/

Install CRDs and deploy Prometheus-Operator:

    helm install coreos/prometheus-operator --name prometheus-operator --namespace monitoring --set rbacEnable=false

Installs bundle of alertmanager, prometheus, exporter-coredns, exporter-kube-controller-manager, exporter-kube-dns, exporter-kube-etcd, exporter-kube-scheduler, exporter-kube-state, exporter-kubelets, exporter-kubernetes, exporter-node, grafana - All from CoreOS Helm Repo.

    helm install coreos/kube-prometheus --name kube-prometheus --namespace monitoring --set global.rbacEnable=false

PS: The version numbers in the Helm charts, for example for Grafana, is sometimes a few months old. This can be overriden by changing Values.yaml or by using --set to helm.

## Configuration

The Prometheus Operator will configure Prometheus and related components using Kubernetes CRD objects as it's configuration source.

The Prometheus CRD contains configuration for the deployment of Prometheus itself.

The Alertmanager CRD ...

The ServiceMonitor CRDs contains configuration of which targets Prometheus should scrape. Typically an application will add a ServiceMonitor resource with instruction on how the application can be monitored.

