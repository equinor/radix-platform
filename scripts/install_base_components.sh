#!/bin/bash

# PRECONDITIONS
#
# It is assumed that cluster is installed using the cluster_install.sh script
#
# PURPOSE
#
# The purpose of the shell script is to set up all base
# components of the cluster
#
# To run this script from terminal:
# SUBSCRIPTION_ENVIRONMENT=aa CLUSTER_NAME=dd ./install_base_components.sh
#
# Example: Configure DEV, use default settings
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="cluster1" ./install_base_components.sh
#
# Example: Configure PROD, use default settings
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

# We don't use Helm to add extra resources any more. Instead we use three different methods:
# For resources that don't need any change: yaml file in manifests/ directory
# Resources that need non-secret customizations: inline the resource in this script and use environment variables
# Resources that need secret values: store the entire yaml file in Azure KeyVault

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

### Check for Azure login

echo "Checking Azure account information"

AZ_ACCOUNT=`az account list | jq ".[] | select(.isDefault == true)"`

echo -n "You are logged in to subscription "
echo -n $AZ_ACCOUNT | jq '.id'

echo -n "Which is named " 
echo -n $AZ_ACCOUNT | jq '.name'

echo -n "As user " 
echo -n $AZ_ACCOUNT | jq '.user.name'

echo 
read -p "Is this correct? (Y/n) " correct_az_login
if [[ $correct_az_login =~ (N|n) ]]; then
  echo "Please use 'az login' command to login to the correct account. Quitting."
  exit 1
fi

# Read credentials from keyvault
echo "Getting Slack API Token"
SLACK_TOKEN="$(az keyvault secret show --vault-name $VAULT_NAME --name slack-token | jq -r .value)"

# Connect kubectl
echo "Getting cluster credentials"
az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$CLUSTER_NAME"

# Apply RBAC config for helm/tiller
echo "Applying RBAC config for helm/tiller"
kubectl apply -f manifests/rbac-config-helm.yaml

# Install Helm
echo "Initializing and/or upgrading helm in cluster"
#curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
#chmod 700 get_helm.sh
#./get_helm.sh --no-sudo -v "$HELM_VERSION"
helm init --service-account tiller --upgrade --wait
#rm -f ./get_helm.sh

# Install cert-manager

# Apply CRDs
echo "Installing cert-manager"
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml

kubectl create namespace cert-manager

# Create some empty TLS secrets that are required for cert-manager to start
kubectl apply -n cert-manager -f manifests/cert-manager-secrets.yaml

kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Install cert-manager using helm
# We also disable the admissions webhook since it's only causing problems
helm upgrade --install cert-manager \
    --namespace cert-manager \
    --version v0.6.0 \
    --set ingressShim.defaultIssuerName=letsencrypt-prod \
    --set ingressShim.defaultIssuerKind=ClusterIssuer \
    --set webhook.enabled=false \
    stable/cert-manager

kubectl label namespace cert-manager certmanager.k8s.io/disable-validation-

# Create a letsencrypt production issuer for cert-manager:
kubectl apply -f manifests/production-issuer.yaml

# Install nginx-ingress:
echo "Installing nginx-ingress"
helm upgrade --install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true --set controller.stats.enabled=true --set controller.metrics.enabled=true --set controller.externalTrafficPolicy=Local

# Create a storageclass
kubectl apply -f manifests/storageclass.yaml

# Install prometheus-operator
echo "Installing prometheus-operator"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name prometheus-operator-values \
    --file prometheus-operator-values.yaml

helm upgrade --install prometheus-operator stable/prometheus-operator -f prometheus-operator-values.yaml

rm -f prometheus-operator-values.yaml


# Install Prometheus Ingress with HTTP Basic Authentication

# To generate a new file: `htpasswd -c ./auth prometheus`
# This file MUST be named `auth` when creating the secret!

az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name prometheus-basic-auth \
    --file auth

kubectl create secret generic prometheus-htpasswd --from-file auth

rm -f auth

# Create a custom ingress for prometheus that adds HTTP Basic Auth

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: prometheus-htpasswd
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required - ok"
  labels:
    app: prometheus
  name: prometheus-basic-auth
spec:
  rules:
  - host: prometheus.$CLUSTER_NAME.$DNS_ZONE
    http:
      paths:
      - backend:
          serviceName: prometheus-operator-prometheus
          servicePort: 9090
        path: /
  tls:
  - hosts:
    - prometheus.$CLUSTER_NAME.$DNS_ZONE
    secretName: prometheus-tls
EOF

# Install grafana
echo "Installing grafana"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name grafana-secrets \
    --file grafana-secrets.yaml

kubectl apply -f grafana-secrets.yaml

rm -f grafana-secrets.yaml

helm upgrade --install grafana stable/grafana -f manifests/grafana-values.yaml \
    --set ingress.hosts[0]=grafana."$CLUSTER_NAME.$DNS_ZONE" \
    --set ingress.tls[0].hosts[0]=grafana."$CLUSTER_NAME.$DNS_ZONE" \
    --set ingress.tls[0].secretName=grafana-tls \
    --set env.GF_SERVER_ROOT_URL=https://grafana."$CLUSTER_NAME.$DNS_ZONE"


# Install external-dns
echo "Installing external-dns"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name external-dns-azure-secret \
    --file external-dns-azure-secret.yaml

kubectl apply -f external-dns-azure-secret.yaml

helm upgrade --install external-dns stable/external-dns --set rbac.create=true --set interval=10s --set txtOwnerId=$CLUSTER_NAME --set provider=azure --set azure.secretName=external-dns-azure-secret --set domainFilters[0]=$DNS_ZONE

rm -f external-dns-azure-secret.yaml

# Install kubed
echo "Installing kubed"
helm repo add appscode https://charts.appscode.com/stable/
helm repo update

helm upgrade --install appscode/kubed --name kubed --version 0.9.0 \
  --namespace kube-system \
  --set apiserver.enabled=false \
  --set config.clusterName=$CLUSTER_NAME \
  --set rbac.create=true \
  --set enableAnalytics=false

# Add Radix helm repo

echo "Adding ACR helm repo "$HELM_REPO""
az acr helm repo add --name "$HELM_REPO"
helm repo update

# Install humio
echo "Installing humio"

az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name humio-values \
    --file humio-values.yaml

helm upgrade --install humio \
    "$HELM_REPO"/humio \
    --set clusterFQDN=$CLUSTER_NAME.$DNS_ZONE \
    -f humio-values.yaml

rm -f humio-values.yaml

# Install radix-operator
echo "Installing radix-operator"
helm upgrade --install radix-operator \
    "$HELM_REPO"/radix-operator \
    --set dnsZone="$DNS_ZONE" \
    --set appAliasBaseURL="app.$DNS_ZONE" \
    --set prometheusName="$PROMETHEUS_NAME" \
    --set imageRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set clusterName="$CLUSTER_NAME" \
    --set image.tag=release-latest

# Install radix-e2e-monitoring
echo "Installing radix-e2e-monitoring"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name radix-e2e-monitoring \
    --file radix-e2e-monitoring.yaml

helm upgrade --install radix-e2e-monitoring \
    "$HELM_REPO"/radix-e2e-monitoring \
    --set clusterFQDN=$CLUSTER_NAME.$DNS_ZONE \
    -f radix-e2e-monitoring.yaml

rm -f radix-e2e-monitoring.yaml

# Notify on slack channel
echo "Notifying on Slack"
helm upgrade --install radix-boot-notify \
    "$HELM_REPO"/slack-notification \
    --set channel="$SLACK_CHANNEL" \
    --set slackToken="$SLACK_TOKEN" \
    --set text="Base components have been installed or updated on $CLUSTER_NAME."


# Patching kube-dns metrics
#
# TODO: Even with this, kube-dns is not discovered in prometheus. Needs to be debugged.
# 
# echo "Patching kube-dns metrics"
# kubectl patch deployment -n kube-system kube-dns-v20 \
#     --patch "$(cat ./manifests/kube-dns-metrics-patch.yaml)"
# 