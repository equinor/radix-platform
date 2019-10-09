#!/bin/bash

# PRECONDITIONS
#
# It is assumed that cluster is installed using the aks/bootstrap.sh script

# PURPOSE
#
# The purpose of the shell script is to set up all base
# components of the cluster

# USAGE
#
# To run this script from terminal:
# SUBSCRIPTION_ENVIRONMENT=aa CLUSTER_NAME=dd ./install_base_components.sh
#
# Example: Configure DEV, use default settings
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="cluster1" ./install_base_components.sh
#
# Example: Configure Playground, use default settings
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="playground-1" CLUSTER_TYPE="playground" ./install_base_components.sh
#
# Example: Configure PROD, use default settings
# SUBSCRIPTION_ENVIRONMENT="prod" CLUSTER_NAME="cluster1" CLUSTER_TYPE="production" ./install_base_components.sh
#
# Example: Configure a dev cluster to use custom configs
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="cluster1" FLUX_GITOPS_BRANCH=testing-something FLUX_GITOPS_DIR=development-configs ./install_base_components.sh

# REQUIRED ENVIRONMENT VARS
#
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
#   USER_PROMPT                 (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)
#
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
    echo "Please provide SUBSCRIPTION_ENVIRONMENT. Value must be one of: \"prod\", \"dev\", \"test\"."
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

if [[ -z "$RADIX_API_PREFIX" ]]; then
  if [ "$CLUSTER_TYPE" = "production" ] || [ "$CLUSTER_TYPE" = "playground" ]; then
    RADIX_API_PREFIX="server-radix-api-prod"
  else
    RADIX_API_PREFIX="server-radix-api-qa"
  fi
fi

if [[ -z "$RADIX_WEBHOOK_PREFIX" ]]; then
   if [ "$CLUSTER_TYPE" = "production" ] || [ "$CLUSTER_TYPE" = "playground" ]; then
    RADIX_WEBHOOK_PREFIX="webhook-radix-github-webhook-prod"
  else
    RADIX_WEBHOOK_PREFIX="webhook-radix-github-webhook-qa"
  fi
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
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
echo -e "CICDCANARY_IMAGE_TAG    : $CICDCANARY_IMAGE_TAG"
echo -e "RADIX_API_PREFIX        : $RADIX_API_PREFIX"
echo -e "RADIX_WEBHOOK_PREFIX    : $RADIX_WEBHOOK_PREFIX"
echo -e "USER_PROMPT             : $USER_PROMPT"
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

if [[ $USER_PROMPT == true ]]; then
  read -p "Is this correct? (Y/n) " correct_az_login
  if [[ $correct_az_login =~ (N|n) ]]; then
    echo "Please use 'az login' command to login to the correct account. Quitting."
    exit 1
  fi
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

if [[ "$SUBSCRIPTION_ENVIRONMENT" != "test" ]]; then
  echo "Getting Slack API Token"
  SLACK_TOKEN="$(az keyvault secret show --vault-name $VAULT_NAME --name slack-token | jq -r .value)"
fi


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

# Install the CustomResourceDefinition resources separately
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl create namespace cert-manager

### Create some empty TLS secrets that are required for cert-manager to start
## kubectl apply -n cert-manager -f manifests/cert-manager-secrets.yaml


# Label the cert-manager namespace to disable resource validation
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
# We also disable the admissions webhook since it's only causing problems
helm upgrade --install cert-manager \
  --namespace cert-manager \
  --version v0.8.1 \
  --set global.rbac.create=true \
  --set ingressShim.defaultIssuerName=letsencrypt-prod \
  --set ingressShim.defaultIssuerKind=ClusterIssuer \
  --set ingressShim.defaultACMEChallengeType="dns01" \
  --set ingressShim.defaultACMEDNS01ChallengeProvider="azure-dns" \
  --set webhook.enabled=false \
  jetstack/cert-manager

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

###########
# !! Work in progress. OAUTH2_PROXY is NOT ready for production
##########

# Set up templated configmap for prometheus oauth2 proxy
# OAUTH2_PROXY_CLIENT_ID is the Azure app ID for Prometheus

# OAUTH2_PROXY_CLIENT_ID_dev='cac8523e-81c3-499e-80a3-4d84e685a3f7'
# OAUTH2_PROXY_CLIENT_ID_prod='1151f027-569e-41a7-8cb4-601c7a408573'

# OAUTH2_PROXY_CLIENT_ID_VAR="OAUTH2_PROXY_CLIENT_ID_${SUBSCRIPTION_ENVIRONMENT}"
# OAUTH2_PROXY_CLIENT_ID="${!OAUTH2_PROXY_CLIENT_ID_VAR}"

# # OAUTH2_PROXY_CLIENT_ID: 130124d4-aa0e-439a-90a9-8983f610e594

# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: prometheus-oauth2-proxy-config
# data:
#   OAUTH2_PROXY_REDIRECT_URL: https://prometheus-oauth2.$CLUSTER_NAME.$DNS_ZONE/oauth2/callback
#   OAUTH2_PROXY_CLIENT_ID: ${OAUTH2_PROXY_CLIENT_ID}
# EOF

# # Set up secret used by the prometheus oauth2 proxy
# #
# # You need an app registration in Azure for Promotheus so that OAuth2 can authenticate against it
# #
# # To generate a new file:
# # 1) Generate a client secret (app password) in the Azure app registration
# # 2) Generate a cookie secret using `python -c 'import os,base64; print base64.urlsafe_b64encode(os.urandom(16))'`
# # 3) Run `echo -n '<client-secret-from-step-1>' | base64`
# # 4) Run `echo -n '<client-secret-from-step-2>' | base64`
# # 5) Fill this template, save it as e.g. secrets.yaml, and save it to the keyvault in Azure:
# #    az keyvault secret set --name prometheus-oauth2-proxy-secrets --vault-name radix-vault-<dev|prod> --file secrets.yaml
# #
# # apiVersion: v1
# # kind: Secret
# # type: Opaque
# # metadata:
# #   name: prometheus-oauth2-proxy-secrets
# # data:
# #   OAUTH2_PROXY_CLIENT_SECRET: <secret-from-step-3>
# #   OAUTH2_PROXY_COOKIE_SECRET: <secret-from-step-4>

# az keyvault secret download \
#     --vault-name $VAULT_NAME \
#     --name prometheus-oauth2-proxy-secrets \
#     --file prometheus-oauth2-proxy-secrets.yaml

# # kubectl create secret generic prometheus-oauth2-proxy-secrets --from-file prometheus-oauth2-proxy-secrets.yaml
# kubectl apply -f prometheus-oauth2-proxy-secrets.yaml

# rm -f prometheus-oauth2-proxy-secrets.yaml

###########
# End OAUTH2_PROXY code
##########


helm upgrade --install prometheus-operator stable/prometheus-operator \
  --version 6.7.3 \
  -f manifests/prometheus-operator-values.yaml \
  --set prometheus.prometheusSpec.serviceMonitorSelector.any=true

# Install Prometheus Ingress with HTTP Basic Authentication

# To generate a new file: `htpasswd -c ./auth prometheus`
# This file MUST be named `auth` when creating the secret!
htpasswd -cb auth prometheus "$(az keyvault secret show --vault-name $VAULT_NAME --name prometheus-token | jq -r .value)"

kubectl create secret generic prometheus-htpasswd \
  --from-file auth --dry-run -o yaml |
  kubectl apply -f -

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

# Install Prometheus Ingress that maps to the OAuth2 Proxy sidecar (specified in ./manifests/prometheus-operator-values.yaml)

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
  labels:
    app: prometheus
  name: prometheus-oauth2-auth
spec:
  rules:
  - host: prometheus-oauth2.$CLUSTER_NAME.$DNS_ZONE
    http:
      paths:
      - backend:
          serviceName: prometheus-operator-prometheus
          servicePort: 4180
        path: /
  tls:
  - hosts:
    - prometheus-oauth2.$CLUSTER_NAME.$DNS_ZONE
    secretName: cluster-wildcard-tls-cert
EOF

# Change kubelet ServiceMonitor from https to http, ref https://github.com/coreos/prometheus-operator/issues/1522

kubectl patch servicemonitor prometheus-operator-kubelet --type=merge \
     --patch "$(cat ./manifests/kubelet-service-monitor-patch.yaml)"

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
(AAD_APP_NAME="radix-cluster-aad-server-${SUBSCRIPTION_ENVIRONMENT}" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" USER_PROMPT="$USER_PROMPT" ./add_reply_url_for_cluster.sh)
wait # wait for subshell to finish

#######################################################################################
### Install prerequisites for external-dns (flux handles the main installation)
###

echo "Installing external-dns secret"
az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name external-dns-azure-secret \
    --file external-dns-azure-secret.yaml

kubectl apply -f external-dns-azure-secret.yaml

rm -f external-dns-azure-secret.yaml

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
# Create radix platform shared configs and secrets
# Create 2 secrets for Radix platform radix-sp-acr-azure and radix-docker

echo ""
echo "Start on radix platform shared configs and secrets..."

echo "Creating radix-sp-acr-azure secret"
az keyvault secret download \
    --vault-name "$VAULT_NAME" \
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

echo "Done."

#######################################################################################
### Install Flux

echo ""
(AZ_INFRASTRUCTURE_ENVIRONMENT="$SUBSCRIPTION_ENVIRONMENT" \
  CLUSTER_NAME="$CLUSTER_NAME" \
  CLUSTER_TYPE="$CLUSTER_TYPE" \
  GIT_REPO="$FLUX_GITOPS_REPO" \
  GIT_BRANCH="$FLUX_GITOPS_BRANCH" \
  GIT_DIR="$FLUX_GITOPS_DIR" \
  ./install_flux.sh)
wait

#######################################################################################
### Install Radix CICD Canary
###

echo ""
echo "Install Radix CICD Canary"
az keyvault secret download \
  --vault-name "$VAULT_NAME" \
  --name radix-cicd-canary-values \
  --file radix-cicd-canary-values.yaml

helm upgrade --install radix-cicd-canary \
  "$HELM_REPO"/radix-cicd-canary \
  --namespace radix-cicd-canary \
  --set clusterFqdn="$CLUSTER_NAME.$DNS_ZONE" \
  --set image.tag="$CICDCANARY_IMAGE_TAG" \
  --set imageCredentials.registry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
  --set clusterType="$CLUSTER_TYPE" \
  --set radixApiPrefix="$RADIX_API_PREFIX" \
	--set radixWebhookPrefix="$RADIX_WEBHOOK_PREFIX" \
  --set sleepIntervalTestRuns=300 \
  -f radix-cicd-canary-values.yaml

rm -f radix-cicd-canary-values.yaml
echo "Done."

#######################################################################################
### Install prerequisites for Velero
### 

echo ""
echo "Installing Velero prerequisites..."

AZ_VELERO_SECRET_NAME="velero-credentials"
VELERO_NAMESPACE="velero"
AZ_VELERO_SECRET_PAYLOAD_FILE="./velero-credentials"

# Create secret for az credentials
az keyvault secret download \
   --vault-name "$VAULT_NAME" \
   --name "$AZ_VELERO_SECRET_NAME" \
   -f "$AZ_VELERO_SECRET_PAYLOAD_FILE"

kubectl create ns "$VELERO_NAMESPACE"
kubectl create secret generic cloud-credentials --namespace "$VELERO_NAMESPACE" \
   --from-env-file="$AZ_VELERO_SECRET_PAYLOAD_FILE" \
   --dry-run -o yaml \
   | kubectl apply -f -

rm "$AZ_VELERO_SECRET_PAYLOAD_FILE"

# Create the cluster specific blob container
AZ_VELERO_STORAGE_ACCOUNT_ID="radixvelero${SUBSCRIPTION_ENVIRONMENT}"

az storage container create -n "$CLUSTER_NAME" \
    --public-access off \
    --account-name "$AZ_VELERO_STORAGE_ACCOUNT_ID" \
    2>&1 >/dev/null

# Create configMap that will hold the cluster specific values that Flux will later use when it manages the deployment of Velero
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: velero-flux-values
  namespace: velero
data:
  values: |
    configuration:
      backupStorageLocation:
        bucket: $CLUSTER_NAME
        config:
          storageAccount: $AZ_VELERO_STORAGE_ACCOUNT_ID
EOF

echo "Done."
echo ""


#######################################################################################
### Notify on slack channel
###

if [[ "$SUBSCRIPTION_ENVIRONMENT" != "test" ]]; then
  echo "Notifying on Slack"
  helm upgrade --install radix-boot-notify \
      "$HELM_REPO"/slack-notification \
      --set channel="$SLACK_CHANNEL" \
      --set slackToken="$SLACK_TOKEN" \
      --set text="Base components have been installed or updated on $CLUSTER_NAME."
fi


#######################################################################################
### Patching kube-dns metrics
###

# TODO: Even with this, kube-dns is not discovered in prometheus. Needs to be debugged.
# 
# echo "Patching kube-dns metrics"
# kubectl patch deployment -n kube-system kube-dns-v20 \
#     --patch "$(cat ./manifests/kube-dns-metrics-patch.yaml)"
# 