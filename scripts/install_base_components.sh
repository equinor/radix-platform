#!/bin/bash

# PRECONDITIONS
#
# It is assumed that cluster is installed using the cluster_install.sh script
# and that the current context is that of the cluster
#
# PURPOSE
#
# The purpose of the shell script is to set up all base
# components of the cluster
#
# To run this script from terminal:
# SUBSCRIPTION_ENVIRONMENT=aa CLUSTER_NAME=dd ./install_base_components.sh
#
# Example: Configure DEV, use defaul settings
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="cluster1" ./install_base_components.sh
#
# Example: Configure PROD, use defaul settings
# SUBSCRIPTION_ENVIRONMENT="prod" CLUSTER_NAME="cluster1" ./install_base_components.sh
#
# Input environment variables:
#   SUBSCRIPTION_ENVIRONMENT    (Mandatory. Example: prod|dev)
#   CLUSTER_NAME                (Mandatory. Example: prod42)
#   DNS_ZONE                    (Optional. Example:e.g. radix.equinor.com|dev.radix.equinor.com)
#   VAULT_NAME                  (Optional. Example: radix-vault-prod|radix-vault-dev|radix-boot-dev-vault)
#   RESOURCE_GROUP              (Optional. Example: "clusters")
#   HELM_VERSION                (Optional. Defaulted if omitted)
#   HELM_REPO                   (Optional. Example: radixprod|radixdev)
#   SLACK_CHANNEL               (Optional. Defaulted if omitted)
#   PROMETHEUS_NAME             (Optional. Defaulted if omitted)
#
# CREDENTIALS:
# The script expects the slack-token to be found as secret in keyvault.

# Validate mandatory input
if [[ -z "$SUBSCRIPTION_ENVIRONMENT" ]]; then
    echo "Please provide SUBSCRIPTION_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

# Set default values for optional input
if [[ -z "$DNS_ZONE" ]]; then
    DNS_ZONE="radix.equinor.com"
    if [[ "$SUBSCRIPTION_ENVIRONMENT" != "prod" ]]; then
        DNS_ZONE="${SUBSCRIPTION_ENVIRONMENT}.${DNS_ZONE}"
    fi
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="clusters"
fi

if [[ -z "$VAULT_NAME" ]]; then
    VAULT_NAME="radix-vault-$SUBSCRIPTION_ENVIRONMENT"
fi

if [[ -z "$HELM_VERSION" ]]; then
    HELM_VERSION="latest"
fi

if [[ -z "$HELM_REPO" ]]; then
    HELM_REPO="radix${SUBSCRIPTION_ENVIRONMENT}"
fi

if [[ -z "$SLACK_CHANNEL" ]]; then
    SLACK_CHANNEL="CCFLFKM39"
fi

if [[ -z "$PROMETHEUS_NAME" ]]; then
    PROMETHEUS_NAME="radix-stage1"
fi

echo -e ""
echo -e "Start deploy of base components using the following settings:"
echo -e "SUBSCRIPTION_ENVIRONMENT: $SUBSCRIPTION_ENVIRONMENT"
echo -e "CLUSTER_NAME            : $CLUSTER_NAME"
echo -e "DNS_ZONE                : $DNS_ZONE"
echo -e "VAULT_NAME              : $VAULT_NAME"
echo -e "RESOURCE_GROUP          : $RESOURCE_GROUP"
echo -e "HELM_VERSION            : $HELM_VERSION"
echo -e "HELM_REPO               : $HELM_REPO"
echo -e "SLACK_CHANNEL           : $SLACK_CHANNEL"
echo -e ""

# Step 1: Read credentials from keyvault
SLACK_TOKEN="$(az keyvault secret show --vault-name $VAULT_NAME --name slack-token | jq -r .value)"

# Step 2: Connect kubectl
az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$CLUSTER_NAME"

# Step 3: Apply RBAC config for helm/tiller
kubectl apply -f ./patch/rbac-config-helm.yaml

echo "Applied RBAC for helm/tiller"

# Step 4: Install Helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh --no-sudo -v "$HELM_VERSION"
helm init --service-account tiller --upgrade --wait
rm -f ./get_helm.sh

echo "Helm initialized"

# Step 5: Patching kube-dns metrics
kubectl patch deployment \
    -n kube-system \
    kube-dns-v20 \
    --patch "$(cat ./patch/kube-dns-metrics-patch.yaml)"

echo "Patched kube-dns metrics"

# Step 6: Adding helm repo
az acr helm repo add --name "$HELM_REPO"
helm repo update
echo "Acr helm repo "$HELM_REPO" was added"

# Step 7: Stage 0
helm upgrade \
    --install radix-stage0 \
    "$HELM_REPO"/radix-stage0 \
    --namespace default \
    --version 1.0.4
echo "Stage 0 completed"

# Step 8: Stage 1
az keyvault secret download \
    --vault-name "$VAULT_NAME" \
    --name radix-stage1-values-"$SUBSCRIPTION_ENVIRONMENT" \
    --file radix-stage1-values-"$SUBSCRIPTION_ENVIRONMENT".yaml

helm upgrade \
    --install radix-stage1 \
    "$HELM_REPO"/radix-stage1 \
    --namespace default \
    --version 1.0.60 \
    --set radix-e2e-monitoring.clusterFQDN="$CLUSTER_NAME.$DNS_ZONE" \
    --set grafana.ingress.hosts[0]=grafana."$CLUSTER_NAME.$DNS_ZONE" \
    --set grafana.ingress.tls[0].hosts[0]=grafana."$CLUSTER_NAME.$DNS_ZONE" \
    --set grafana.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set grafana.env.GF_SERVER_ROOT_URL=https://grafana."$CLUSTER_NAME.$DNS_ZONE" \
    --set kube-prometheus.prometheus.ingress.hosts[0]=prometheus."$CLUSTER_NAME.$DNS_ZONE" \
    --set kube-prometheus.prometheus.ingress.tls[0].hosts[0]=prometheus."$CLUSTER_NAME.$DNS_ZONE" \
    --set kube-prometheus.prometheus.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set kubed.config.clusterName="$CLUSTER_NAME" \
    --set externalDns.clusterName="$CLUSTER_NAME" \
    --set externalDns.zoneName="$DNS_ZONE" \
    --set externalDns.environment="$SUBSCRIPTION_ENVIRONMENT" \
    --set clusterWildcardCert.clusterDomain="$CLUSTER_NAME.$DNS_ZONE" \
    --set clusterWildcardCert.appDomain=app."$DNS_ZONE" \
    --set humio.clusterFQDN="$CLUSTER_NAME.$DNS_ZONE" \
    -f radix-stage1-values-"$SUBSCRIPTION_ENVIRONMENT".yaml

echo "Stage 1 completed"

# Step 9: Delete stage 1 secret
rm -f ./radix-stage1-values-"$SUBSCRIPTION_ENVIRONMENT".yaml

# Step 10: Install operator
helm upgrade \
    --install radix-operator \
    "$HELM_REPO"/radix-operator \
    --namespace default \
    --set dnsZone="$DNS_ZONE" \
    --set appAliasBaseURL="app.$DNS_ZONE" \
    --set prometheusName="$PROMETHEUS_NAME" \
    --set imageRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set clusterName="$CLUSTER_NAME" \
    --set image.tag=release-latest

echo "Operator installed"

# Step 11: Patching kubelet service-monitor
kubectl patch servicemonitors \
    radix-stage1-exporter-kubelets \
    --type merge \
    --patch "$(cat ./patch/kubelet-service-monitor-patch.yaml)"

echo "Patched kubelet service-monitor"

# Step 12: Notify on slack channel
helm upgrade \
    --install radix-boot-notify \
    "$HELM_REPO"/slack-notification \
    --set channel="$SLACK_CHANNEL" \
    --set slackToken="$SLACK_TOKEN" \
    --set text="Cluster $CLUSTER_NAME is now deployed."

echo "Notified on slack channel"

# Step 13: Remove credentials file
rm -f ./credentials