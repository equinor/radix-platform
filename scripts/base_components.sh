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
# SUBSCRIPTION_ENVIRONMENT=aa VAULT_NAME=bb CLUSTER_NAME=cc HELM_VERSION=dd HELM_REPO=dd ./base_components.sh
#
# Input environment variables:
#   SUBSCRIPTION_ENVIRONMENT (e.g. prod|dev)
#   VAULT_NAME (e.g. radix-boot-dev-vault)
#   CLUSTER_NAME (e.g. prod)
#   HELM_VERSION (defaulted if omitted)
#   HELM_REPO (e.g. radixdev)
#   SLACK_CHANNEL (defaulted if omitted)
#
# Secret environment variables (downloaded from keyvault):
#   SLACK_TOKEN

if [[ -z "$HELM_VERSION" ]]; then
    HELM_VERSION="latest"
fi

if [[ -z "$SLACK_CHANNEL" ]]; then
    SLACK_CHANNEL="CCFLFKM39"
fi

# Step 1: Apply RBAC config for helm/tiller
kubectl apply -f ./patch/rbac-config-helm.yaml

echo "Applied RBAC for helm/tiller"

# Step 2: Install Helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh --no-sudo -v "$HELM_VERSION"
helm init --service-account tiller --upgrade --wait
rm -f ./get_helm.sh

echo "Helm initialized"

# Step 3: Patching kube-dns metrics
kubectl patch deployment \
    -n kube-system \
    kube-dns-v20 \
    --patch ./patch/kube-dns-metrics-patch.yaml

echo "Patched kube-dns metrics"

# Step 4: Adding helm repo
az acr helm repo add --name "$HELM_REPO"
helm repo update
echo "Acr helm repo $HELM_REPO was added"

# Step 5: Stage 0
helm upgrade \
    --install --force radix-stage0 \
    $HELM_REPO/radix-stage0 \
    --namespace default \
    --version 1.0.2
echo "Stage 0 completed"

# Step 5: Stage 1
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name radix-stage1-values-$SUBSCRIPTION_ENVIRONMENT \
    --file radix-stage1-values-$SUBSCRIPTION_ENVIRONMENT.yaml

helm upgrade \
    radix-stage1 \
    $HELM_REPO/radix-stage1 \
    --namespace default \
    --version 1.0.37 \
    --set radix-e2e-monitoring.clusterFQDN=$CLUSTER_NAME.$SUBSCRIPTION_ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.hosts[0]=grafana.$CLUSTER_NAME.$SUBSCRIPTION_ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.tls[0].hosts[0]=grafana.$CLUSTER_NAME.$SUBSCRIPTION_ENVIRONMENT.radix.equinor.com \
    --set grafana.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set grafana.env.GF_SERVER_ROOT_URL=https://grafana.$CLUSTER_NAME.$SUBSCRIPTION_ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.hosts[0]=prometheus.$CLUSTER_NAME.$SUBSCRIPTION_ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.tls[0].hosts[0]=prometheus.$CLUSTER_NAME.$SUBSCRIPTION_ENVIRONMENT.radix.equinor.com \
    --set kube-prometheus.prometheus.ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set kubed.config.clusterName=$CLUSTER_NAME \
    --set externalDns.clusterName=$CLUSTER_NAME \
    --set externalDns.environment=$SUBSCRIPTION_ENVIRONMENT \
    --set clusterWildcardCert.clusterName=$CLUSTER_NAME \
    --set clusterWildcardCert.environment=$SUBSCRIPTION_ENVIRONMENT \
    --set radix-kubernetes-api-proxy.clusterFQDN=$CLUSTER_NAME.$SUBSCRIPTION_ENVIRONMENT.radix.equinor.com \
    -f radix-stage1-values-$SUBSCRIPTION_ENVIRONMENT.yaml

echo "Stage 1 completed"

# Step 6: Delete stage 1 secret
rm -f ./radix-stage1-values-$SUBSCRIPTION_ENVIRONMENT.yaml

# Step 7: Install operator
helm upgrade \
    --install --force radix-operator \
    $HELM_REPO/radix-operator \
    --namespace default \
    --set clusterName=$CLUSTER_NAME \
    --set image.tag=release-latest

echo "Operator installed"

# Step 8: Patching kubelet service-monitor
kubectl patch servicemonitors \
    radix-stage1-exporter-kubelets \
    --type merge \
    --patch ./patch/kubelet-service-monitor-patch.yaml

echo "Patched kubelet service-monitor"

# Step 9: Notify on slack channel
#helm upgrade \
#    --install --force radix-boot-notify \
#    $HELM_REPO/slack-notification \
#    --set channel=$SLACK_CHANNEL \
#    --set slackToken=$SLACK_TOKEN \
#    --set text='Cluster $CLUSTER_NAME is now deployed.'

#echo "Notified on slack channel"