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
# Example: Configure Playground, use default settings
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="playground-1" CLUSTER_TYPE="playground" ./install_base_components.sh
#
# Example: Configure DEV, use default settings
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="cluster1" ./install_base_components.sh
#
# Example: Configure PROD, use default settings
# SUBSCRIPTION_ENVIRONMENT="prod" CLUSTER_NAME="cluster1" CLUSTER_TYPE="production" ./install_base_components.sh
#
# Input environment variables:
#   SUBSCRIPTION_ENVIRONMENT    (Mandatory. Example: prod|dev)
#   CLUSTER_NAME                (Mandatory. Example: prod42)
#   CLUSTER_TYPE                (Optional. Defaulted if omitted. ex: "production", "playground", "development")
#   DNS_ZONE                    (Optional. Example:e.g. radix.equinor.com|dev.radix.equinor.com|playground.radix.equinor.com)
#   VAULT_NAME                  (Optional. Example: radix-vault-prod|radix-vault-dev|radix-boot-dev-vault)
#   RESOURCE_GROUP              (Optional. Example: "clusters")
#   HELM_VERSION                (Optional. Defaulted if omitted)
#   HELM_REPO                   (Optional. Example: radixprod|radixdev)
#   SLACK_CHANNEL               (Optional. Defaulted if omitted)
#   PROMETHEUS_NAME             (Optional. Defaulted if omitted)
#   FLUX_GITOPS_REPO            (Optional. Defaulted if omitted)
#   FLUX_GITOPS_BRANCH          (Optional. Defaulted if omitted)
#   FLUX_GITOPS_PATH            (Optional. Defaulted if omitted)
#
# CREDENTIALS:
# The script expects the slack-token to be found as secret in keyvault.

# We don't use Helm to add extra resources any more. Instead we use three different methods:
# For resources that don't need any change: yaml file in manifests/ directory
# Resources that need non-secret customizations: inline the resource in this script and use environment variables
# Resources that need secret values: store the entire yaml file in Azure KeyVault


#######################################################################################
# Styles
__style_yellow="\033[33m"
__style_end="\033[0m"


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting...";  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting...";  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nError: helm not found in PATH. Exiting...";  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nError: jq not found in PATH. Exiting...";  exit 1; }
#printf "All is good."
echo ""


#######################################################################################
### Validate mandatory input
###

if [[ -z "$SUBSCRIPTION_ENVIRONMENT" ]]; then
    echo "Please provide SUBSCRIPTION_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi


#######################################################################################
### Set default values for optional input
###

if [[ -z "$CLUSTER_TYPE" ]]; then
    CLUSTER_TYPE="development"
fi

if [[ -z "$DNS_ZONE" ]]; then
    DNS_ZONE="radix.equinor.com"

    if [[ "$SUBSCRIPTION_ENVIRONMENT" != "prod" ]] && [ "$CLUSTER_TYPE" = "playground" ]; then
      DNS_ZONE="playground.$DNS_ZONE"
    elif [[ "$SUBSCRIPTION_ENVIRONMENT" != "prod" ]]; then
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

if [[ -z "$FLUX_GITOPS_REPO" ]]; then
  FLUX_GITOPS_REPO="git@github.com:equinor/radix-flux.git"
fi

if [[ -z "$FLUX_GITOPS_BRANCH" ]]; then
  if [[ "$SUBSCRIPTION_ENVIRONMENT" == "prod" ]]; then
    FLUX_GITOPS_BRANCH="release"
    FLUX_GITOPS_PATH="production-configs"
  elif [[ "$SUBSCRIPTION_ENVIRONMENT" == "dev" ]] && [ "$CLUSTER_TYPE" == "playground" ]; then
    FLUX_GITOPS_BRANCH="release"
    FLUX_GITOPS_PATH="playground-configs"
  elif [[ "$SUBSCRIPTION_ENVIRONMENT" == "dev" ]] && [ "$CLUSTER_TYPE" == "development" ]; then
    FLUX_GITOPS_BRANCH="master"
    FLUX_GITOPS_PATH="development-configs"
  fi
fi

CICDCANARY_IMAGE_TAG="master-latest"

#######################################################################################
### Ask user to verify inputs and az login
###

# Print inputs
echo -e ""
echo -e "Start deploy of base components using the following settings:"
echo -e "SUBSCRIPTION_ENVIRONMENT: $SUBSCRIPTION_ENVIRONMENT"
echo -e "CLUSTER_NAME            : $CLUSTER_NAME"
echo -e "CLUSTER_TYPE            : $CLUSTER_TYPE"
echo -e "DNS_ZONE                : $DNS_ZONE"
echo -e "VAULT_NAME              : $VAULT_NAME"
echo -e "RESOURCE_GROUP          : $RESOURCE_GROUP"
echo -e "HELM_VERSION            : $HELM_VERSION"
echo -e "HELM_REPO               : $HELM_REPO"
echo -e "SLACK_CHANNEL           : $SLACK_CHANNEL"
echo -e "FLUX_GITOPS_REPO        : $FLUX_GITOPS_REPO"
echo -e "FLUX_GITOPS_BRANCH      : $FLUX_GITOPS_BRANCH"
echo -e "FLUX_GITOPS_PATH        : $FLUX_GITOPS_PATH"
echo -e "CICDCANARY_IMAGE_TAG    : $CICDCANARY_IMAGE_TAG"
echo -e ""

# Check for Azure login
echo "Checking Azure account information"

AZ_ACCOUNT=`az account list | jq ".[] | select(.isDefault == true)"`
echo -n "You are logged in to subscription "
echo -n $AZ_ACCOUNT | jq '.id'
echo -n "Which is named " 
echo -n $AZ_ACCOUNT | jq '.name'
echo -n "As user " 
echo -n $AZ_ACCOUNT | jq '.user.name'
echo ""

read -p "Is this correct? (Y/n) " correct_az_login
if [[ $correct_az_login =~ (N|n) ]]; then
  echo "Please use 'az login' command to login to the correct account. Quitting."
  exit 1
fi

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo ""
echo "Connecting kubectl..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then    
    # Send message to stderr
    echo -e "Error: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 0        
fi


#######################################################################################
### Read secrets from keyvault
###

echo "Getting Slack API Token"
SLACK_TOKEN="$(az keyvault secret show --vault-name $VAULT_NAME --name slack-token | jq -r .value)"


#######################################################################################
### Install Helm and related rbac
###

# Apply RBAC config for helm/tiller
echo "Applying RBAC config for helm/tiller"
kubectl apply -f manifests/rbac-config-helm.yaml

# Install Helm
echo "Initializing and/or upgrading helm in cluster"
helm init --service-account tiller --upgrade --wait
helm repo update


#######################################################################################
### Install cert-manager
###

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
    --set ingressShim.defaultACMEChallengeType="dns01" \
    --set ingressShim.defaultACMEDNS01ChallengeProvider="azure-dns" \
    --set webhook.enabled=false \
    stable/cert-manager

kubectl label namespace cert-manager certmanager.k8s.io/disable-validation-

# Create a letsencrypt production issuer for cert-manager:
clusterissuer_config="cert-manager-production-clusterissuer"
if [ "$CLUSTER_TYPE" = "playground" ]; then
  clusterissuer_config="cert-manager-playground-clusterissuer"
fi

az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name "$clusterissuer_config" \
    --file "${clusterissuer_config}.yaml"

kubectl apply -n cert-manager -f "${clusterissuer_config}.yaml"

rm -f "${clusterissuer_config}.yaml"

#######################################################################################
### Create wildcard certs
###

# Create app wildcard cert
echo "Creating app wildcard cert..."

APP_ALIAS_BASE_URL="app.$DNS_ZONE"

cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: app-wildcard-tls-cert
spec:
  secretName: app-wildcard-tls-cert
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  commonName: "*.$APP_ALIAS_BASE_URL"
  dnsNames:
  - "$APP_ALIAS_BASE_URL"
  acme:
    config:
    - dns01:
        provider: azure-dns
      domains:
      - "*.$APP_ALIAS_BASE_URL"
      - "$APP_ALIAS_BASE_URL"
EOF

# Create cluster wildcard cert
echo "Creating cluster wildcard cert..."

cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: cluster-wildcard-tls-cert
spec:
  secretName: cluster-wildcard-tls-cert
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  commonName: "*.$CLUSTER_NAME.$DNS_ZONE"
  dnsNames:
  - "$CLUSTER_NAME.$DNS_ZONE"
  acme:
    config:
    - dns01:
        provider: azure-dns
      domains:
      - "*.$CLUSTER_NAME.$DNS_ZONE"
      - "$CLUSTER_NAME.$DNS_ZONE"
EOF

# Create active cluster wildcard cert
echo "Creating active cluster wildcard cert..."

cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: active-cluster-wildcard-tls-cert
spec:
  secretName: active-cluster-wildcard-tls-cert
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  commonName: "*.$DNS_ZONE"
  dnsNames:
  - "$DNS_ZONE"
  acme:
    config:
    - dns01:
        provider: azure-dns
      domains:
      - "*.$DNS_ZONE"
      - "$DNS_ZONE"
EOF

# Waiting for cert-manager to create certificate secrets before annotating them...
echo ""
echo "Waiting for cert-manager to create certificate secret app-wildcard-tls-cert before annotating it..."
while [[ "$(kubectl get secret app-wildcard-tls-cert 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo "Certificate secret app-wildcard-tls-cert has been created, annotating it..."
kubectl annotate Secret app-wildcard-tls-cert kubed.appscode.com/sync="app-wildcard-sync=app-wildcard-tls-cert"

echo ""
echo "Waiting for cert-manager to create certificate secret cluster-wildcard-tls-cert before annotating it..."
while [[ "$(kubectl get secret cluster-wildcard-tls-cert 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo "Certificate secret cluster-wildcard-tls-cert has been created, annotating it..."
kubectl annotate Secret cluster-wildcard-tls-cert kubed.appscode.com/sync="cluster-wildcard-sync=cluster-wildcard-tls-cert"

echo ""
echo "Waiting for cert-manager to create certificate secret active-cluster-wildcard-tls-cert before annotating it..."
while [[ "$(kubectl get secret active-cluster-wildcard-tls-cert 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo "Certificate secret active-cluster-wildcard-tls-cert has been created, annotating it..."
kubectl annotate Secret active-cluster-wildcard-tls-cert kubed.appscode.com/sync="active-cluster-wildcard-sync=active-cluster-wildcard-tls-cert"

#######################################################################################
### Create storage classes
###

echo "Creating storage classes"
kubectl apply -f manifests/storageclass-retain.yaml
kubectl apply -f manifests/storageclass-retain-nocache.yaml


#######################################################################################
### Install prometheus-operator
###

echo "Installing prometheus-operator"
helm upgrade --install prometheus-operator stable/prometheus-operator -f manifests/prometheus-operator-values.yaml --set prometheus.prometheusSpec.serviceMonitorSelector.any=true

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
    secretName: cluster-wildcard-tls-cert
EOF

# Change kubelet ServiceMonitor from https to http, ref https://github.com/coreos/prometheus-operator/issues/1522

kubectl patch servicemonitor prometheus-operator-kubelet --type=merge \
     --patch "$(cat ./manifests/kubelet-service-monitor-patch.yaml)"

#######################################################################################
### Install nginx-ingress:
###

echo "Installing nginx-ingress"
helm upgrade --install nginx-ingress stable/nginx-ingress \
  --set controller.publishService.enabled=true \
  --set controller.stats.enabled=true \
  --set controller.metrics.enabled=true \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.metrics.serviceMonitor.enabled=true \
  -f ./manifests/nginx-configmap-values.yaml

#######################################################################################
### Install grafana
###

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
    --set ingress.tls[0].secretName=cluster-wildcard-tls-cert \
    --set env.GF_SERVER_ROOT_URL=https://grafana."$CLUSTER_NAME.$DNS_ZONE"

# Add grafana replyUrl to AAD app    
(AAD_APP_NAME="radix-cluster-aad-server-${SUBSCRIPTION_ENVIRONMENT}" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" ./add_reply_url_for_cluster.sh)
wait # wait for subshell to finish

#######################################################################################
### Install external-dns
###

echo "Installing external-dns"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name external-dns-azure-secret \
    --file external-dns-azure-secret.yaml

kubectl apply -f external-dns-azure-secret.yaml

helm upgrade --install external-dns stable/external-dns --set rbac.create=true --set interval=10s --set txtOwnerId=$CLUSTER_NAME --set provider=azure --set azure.secretName=external-dns-azure-secret --set domainFilters[0]=$DNS_ZONE --set policy=sync

rm -f external-dns-azure-secret.yaml


#######################################################################################
### Install kubed
###

echo "Installing kubed"
helm repo add appscode https://charts.appscode.com/stable/
helm repo update

helm upgrade --install kubed appscode/kubed --version 0.9.0 \
  --namespace kube-system \
  --set apiserver.enabled=false \
  --set config.clusterName=$CLUSTER_NAME \
  --set rbac.create=true \
  --set enableAnalytics=false


#######################################################################################
### Add Radix helm repo
### 

echo "Adding ACR helm repo "$HELM_REPO""
az acr helm repo add --name "$HELM_REPO"
helm repo update


#######################################################################################
### For network security policy applied by operator to work, the namespace hosting prometheus and nginx-ingress-controller need to be labeled
kubectl label ns default purpose=radix-base-ns --overwrite


#######################################################################################
### Install backup of radix custom resources (RR, RA, RD)
### https://github.com/equinor/radix-backup-cr

echo "Installing radix-backup-cr"

helm upgrade --install radix-backup-cr \
    $HELM_REPO/radix-backup-cr \
    --namespace default \
    --set imageRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set image.tag=release-latest


#######################################################################################
### Install radix-e2e-monitoring
###

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


#######################################################################################
# Create radix platform shared configs and secrets
# Create 2 secrets for Radix platform radix-sp-acr-azure and radix-docker
echo "Creating radix-sp-acr-azure secret"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name "radix-cr-cicd-${SUBSCRIPTION_ENVIRONMENT}" \
    --file sp_credentials.json

kubectl create secret generic radix-sp-acr-azure --from-file=sp_credentials.json --dry-run -o yaml | kubectl apply -f -

echo "Creating radix-docker secret"
kubectl create secret docker-registry radix-docker \
   --docker-server="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
   --docker-username=$"$(jq -r '.id' sp_credentials.json)" \
   --docker-password="$(jq -r '.password' sp_credentials.json)" \
   --docker-email=radix@statoilsrm.onmicrosoft.com \
   --dry-run -o yaml \
   | kubectl apply -f -

rm -f sp_credentials.json

cat << EOF > radix-platform-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: radix-platform-config
  namespace: default
data:
  platform: |
    dnsZone: "$DNS_ZONE"
    appAliasBaseURL: "app.$DNS_ZONE"
    prometheusName: radix-stage1
    imageRegistry: "radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io"
    clusterName: "$CLUSTER_NAME"
    clusterType: "$CLUSTER_TYPE"
EOF

kubectl apply -f radix-platform-config.yaml
rm radix-platform-config.yaml


#######################################################################################
### Install and configure Flux

FLUX_PRIVATE_KEY_NAME="flux-github-deploy-key-private"
FLUX_PUBLIC_KEY_NAME="flux-github-deploy-key-public"
FLUX_DEPLOY_KEYS_GENERATED=false

FLUX_PRIVATE_KEY=`az keyvault secret show --name "$FLUX_PRIVATE_KEY_NAME" --vault-name "$VAULT_NAME"`
FLUX_PUBLIC_KEY=`az keyvault secret show --name "$FLUX_PUBLIC_KEY_NAME" --vault-name "$VAULT_NAME"`

if [[ -z "$FLUX_PRIVATE_KEY" ]] || [[ -z "$FLUX_PUBLIC_KEY" ]]; then
    echo "Missing flux deploy keys for GitHub in keyvault: $VAULT_NAME"
    echo "Generating flux private and public keys..."
    ssh-keygen -t rsa -b 4096 -N "" -C "gm_radix@equinor.com" -f id_rsa."$SUBSCRIPTION_ENVIRONMENT"
    az keyvault secret set --file=./id_rsa."$SUBSCRIPTION_ENVIRONMENT" --name="$FLUX_PRIVATE_KEY_NAME" --vault-name="$VAULT_NAME"
    az keyvault secret set --file=./id_rsa."$SUBSCRIPTION_ENVIRONMENT".pub --name="$FLUX_PUBLIC_KEY_NAME" --vault-name="$VAULT_NAME"
    rm id_rsa."$SUBSCRIPTION_ENVIRONMENT"
    rm id_rsa."$SUBSCRIPTION_ENVIRONMENT".pub
    FLUX_DEPLOY_KEYS_GENERATED=true
else
    echo "Flux deploy keys for GitHub already exist in keyvault: $VAULT_NAME"
fi

echo ""
echo "Creating $FLUX_PRIVATE_KEY_NAME secret"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name "$FLUX_PRIVATE_KEY_NAME" \
    --file "$FLUX_PRIVATE_KEY_NAME"

kubectl create secret generic "$FLUX_PRIVATE_KEY_NAME" --from-file=identity="$FLUX_PRIVATE_KEY_NAME"
rm "$FLUX_PRIVATE_KEY_NAME"

echo ""
echo "Adding Weaveworks repository to Helm"
helm repo add weaveworks https://weaveworks.github.io/flux > /dev/null

echo ""
echo "Installing Flux with Helm operator"
helm upgrade --install flux \
   --set rbac.create=true \
   --set helmOperator.create=true \
   --set helmOperator.pullSecret=radix-docker \
   --set git.url="$FLUX_GITOPS_REPO" \
   --set git.branch="$FLUX_GITOPS_BRANCH" \
   --set git.path="$FLUX_GITOPS_PATH" \
   --set git.secretName="$FLUX_PRIVATE_KEY_NAME" \
   --set registry.acr.enabled=true \
   weaveworks/flux > /dev/null

echo -e ""
echo -e ""
echo -e "A Flux service has been provisioned in the cluster to follow the GitOps way of thinking."

if [ "$FLUX_DEPLOY_KEYS_GENERATED" = true ]; then
    FLUX_DEPLOY_KEY_NOTIFICATION="*** IMPORTANT ***\nPlease add a new deploy key in the radix-flux repository (https://github.com/equinor/radix-flux/settings/keys) with the value from $FLUX_PUBLIC_KEY_NAME secret in $VAULT_NAME Azure keyvault."
    echo ""
    echo -e "${__style_yellow}$FLUX_DEPLOY_KEY_NOTIFICATION${__style_end}"
    echo ""
fi

#######################################################################################
### Install Radix CICD Canary
###
echo "Install Radix CICD Canary"
az keyvault secret download \
  --vault-name "$VAULT_NAME" \
  --name radix-cicd-canary-values \
  --file radix-cicd-canary-values.yaml

helm upgrade --install radix-cicd-canary \
  "$HELM_REPO"/radix-cicd-canary \
  --namespace radix-cicd-canary \
  --set clusterFQDN="$CLUSTER_NAME.$DNS_ZONE" \
  --set image.tag="$CICDCANARY_IMAGE_TAG" \
  --set imageCredentials.registry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
  --set clusterType="$CLUSTER_TYPE" \
  -f radix-cicd-canary-values.yaml

rm -f radix-cicd-canary-values.yaml

#######################################################################################
### Notify on slack channel
###

echo "Notifying on Slack"
helm upgrade --install radix-boot-notify \
    "$HELM_REPO"/slack-notification \
    --set channel="$SLACK_CHANNEL" \
    --set slackToken="$SLACK_TOKEN" \
    --set text="Base components have been installed or updated on $CLUSTER_NAME."


#######################################################################################
### Patching kube-dns metrics
###

# TODO: Even with this, kube-dns is not discovered in prometheus. Needs to be debugged.
# 
# echo "Patching kube-dns metrics"
# kubectl patch deployment -n kube-system kube-dns-v20 \
#     --patch "$(cat ./manifests/kube-dns-metrics-patch.yaml)"
# 