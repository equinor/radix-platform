#!/bin/bash

#######################################################################################
### PURPOSE
###

# Install required base components in a radix cluster.

#######################################################################################
### PRECONDITIONS
###

# It is assumed that cluster is installed using the aks/bootstrap.sh script
# The script expects the slack-token to be found as secret in keyvault.

# We don't use Helm to add extra resources any more. Instead we use three different methods:
# For resources that don't need any change: yaml file in manifests/ directory
# Resources that need non-secret customizations: inline the resource in this script and use environment variables
# Resources that need secret values: store the entire yaml file in Azure KeyVault

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

# Optional:
# - SLACK_CHANNEL
# - FLUX_GITOPS_REPO
# - FLUX_GITOPS_BRANCH
# - FLUX_GITOPS_PATH
# - USER_PROMPT                 : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Normal usage
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./install_base_components.sh

# Configure a dev cluster to use custom configs
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="please-work-4" FLUX_GITOPS_BRANCH=testing-something FLUX_GITOPS_DIR=development-configs ./install_base_components.sh

#######################################################################################
### START
###

echo ""
echo "Start install of base components... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
  echo -e "\nError: Azure-CLI not found in PATH. Exiting..."
  exit 1
}
hash kubectl 2>/dev/null || {
  echo -e "\nError: kubectl not found in PATH. Exiting..."
  exit 1
}
hash helm 2>/dev/null || {
  echo -e "\nError: helm not found in PATH. Exiting..."
  exit 1
}
hash jq 2>/dev/null || {
  echo -e "\nError: jq not found in PATH. Exiting..."
  exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Overridable input
FLUX_GITOPS_BRANCH_OVERRIDE=$FLUX_GITOPS_BRANCH
FLUX_GITOPS_DIR_OVERRIDE=$FLUX_GITOPS_DIR

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
  echo "Please provide RADIX_ZONE_ENV" >&2
  exit 1
else
  if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
    echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
    exit 1
  fi
  source "$RADIX_ZONE_ENV"
fi

# Return to overrided values, if present
if [[ -n "$FLUX_GITOPS_BRANCH_OVERRIDE" ]]; then
  FLUX_GITOPS_BRANCH=$FLUX_GITOPS_BRANCH_OVERRIDE
fi

if [[ -n "$FLUX_GITOPS_DIR_OVERRIDE" ]]; then
  FLUX_GITOPS_DIR=$FLUX_GITOPS_DIR_OVERRIDE
fi

if [[ -z "$CLUSTER_NAME" ]]; then
  echo "Please provide CLUSTER_NAME" >&2
  exit 1
fi

# Optional inputs

if [[ -z "$SLACK_CHANNEL" ]]; then
  SLACK_CHANNEL="CCFLFKM39"
fi

if [[ -z "$USER_PROMPT" ]]; then
  USER_PROMPT=true
fi

IMAGE_REGISTRY="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Install base components will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  SLACK_CHANNEL                    : $SLACK_CHANNEL"
echo -e "   -  RADIX_API_PREFIX                 : $RADIX_API_PREFIX"
echo -e "   -  RADIX_WEBHOOK_PREFIX             : $RADIX_WEBHOOK_PREFIX"
echo -e "   -  IMAGE_REGISTRY                   : $IMAGE_REGISTRY"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $AZ_SUBSCRIPTION"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
  read -p "Is this correct? (Y/n) " -n 1 -r
  if [[ "$REPLY" =~ (N|n) ]]; then
    echo ""
    echo "Quitting."
    exit 0
  fi
  echo ""
fi

echo ""

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "\nConnecting kubectl..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then
  # Send message to stderr
  echo -e "Error: Cluster \"$CLUSTER_NAME\" not found." >&2
  exit 0
fi
printf "...Done.\n"

#######################################################################################
### Read secrets from keyvault
###

if [[ "$RADIX_ENVIRONMENT" != "test" ]]; then
  printf "\nGetting Slack API Token..."
  SLACK_TOKEN="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name slack-token | jq -r .value)"
  printf "...Done\n"
fi

#######################################################################################
### Install Helm and related rbac
###

(USER_PROMPT="false" ./helm/bootstrap.sh)
wait


#######################################################################################
### Install cert-manager
###

(USER_PROMPT="false" ./cert-manager/bootstrap.sh)
wait


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

# OAUTH2_PROXY_CLIENT_ID_VAR="OAUTH2_PROXY_CLIENT_ID_${RADIX_ENVIRONMENT}"
# OAUTH2_PROXY_CLIENT_ID="${!OAUTH2_PROXY_CLIENT_ID_VAR}"

# # OAUTH2_PROXY_CLIENT_ID: 130124d4-aa0e-439a-90a9-8983f610e594

# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: prometheus-oauth2-proxy-config
# data:
#   OAUTH2_PROXY_REDIRECT_URL: https://prometheus-oauth2.$CLUSTER_NAME.$AZ_RESOURCE_DNS/oauth2/callback
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
#     --vault-name $AZ_RESOURCE_KEYVAULT \
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
htpasswd -cb auth prometheus "$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name prometheus-token | jq -r .value)"

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
  - host: prometheus.$CLUSTER_NAME.$AZ_RESOURCE_DNS
    http:
      paths:
      - backend:
          serviceName: prometheus-operator-prometheus
          servicePort: 9090
        path: /
  tls:
  - hosts:
    - prometheus.$CLUSTER_NAME.$AZ_RESOURCE_DNS
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
  - host: prometheus-oauth2.$CLUSTER_NAME.$AZ_RESOURCE_DNS
    http:
      paths:
      - backend:
          serviceName: prometheus-operator-prometheus
          servicePort: 4180
        path: /
  tls:
  - hosts:
    - prometheus-oauth2.$CLUSTER_NAME.$AZ_RESOURCE_DNS
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
  --vault-name $AZ_RESOURCE_KEYVAULT \
  --name grafana-secrets \
  --file grafana-secrets.yaml

kubectl apply -f grafana-secrets.yaml

rm -f grafana-secrets.yaml

helm upgrade --install grafana stable/grafana -f manifests/grafana-values.yaml \
  --version v3.9.1 \
  --set ingress.hosts[0]=grafana."$CLUSTER_NAME.$AZ_RESOURCE_DNS" \
  --set ingress.tls[0].hosts[0]=grafana."$CLUSTER_NAME.$AZ_RESOURCE_DNS" \
  --set ingress.tls[0].secretName=cluster-wildcard-tls-cert \
  --set env.GF_SERVER_ROOT_URL=https://grafana."$CLUSTER_NAME.$AZ_RESOURCE_DNS"

# Add grafana replyUrl to AAD app
(AAD_APP_NAME="radix-cluster-aad-server-${RADIX_ENVIRONMENT}" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" USER_PROMPT="$USER_PROMPT" ./add_reply_url_for_cluster.sh)
wait # wait for subshell to finish

#######################################################################################
### Install prerequisites for external-dns (flux handles the main installation)
###

echo "Installing external-dns secret"
az keyvault secret download \
  --vault-name $AZ_RESOURCE_KEYVAULT \
  --name external-dns-azure-secret \
  --file external-dns-azure-secret.yaml

kubectl apply -f external-dns-azure-secret.yaml

rm -f external-dns-azure-secret.yaml

#######################################################################################
### Prepare helm
###

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
  --vault-name "$AZ_RESOURCE_KEYVAULT" \
  --name "radix-cr-cicd-${RADIX_ENVIRONMENT}" \
  --file sp_credentials.json

kubectl create secret generic radix-sp-acr-azure --from-file=sp_credentials.json --dry-run -o yaml | kubectl apply -f -

echo "Creating radix-docker secret"
kubectl create secret docker-registry radix-docker \
  --docker-server="radix$RADIX_ENVIRONMENT.azurecr.io" \
  --docker-username=$"$(jq -r '.id' sp_credentials.json)" \
  --docker-password="$(jq -r '.password' sp_credentials.json)" \
  --docker-email=radix@statoilsrm.onmicrosoft.com \
  --dry-run -o yaml |
  kubectl apply -f -

rm -f sp_credentials.json

cat <<EOF >radix-platform-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: radix-platform-config
  namespace: default
data:
  platform: |
    dnsZone: "$AZ_RESOURCE_DNS"
    appAliasBaseURL: "app.$AZ_RESOURCE_DNS"
    prometheusName: radix-stage1
    imageRegistry: "$IMAGE_REGISTRY"
    clusterName: "$CLUSTER_NAME"
    clusterType: "$CLUSTER_TYPE"
EOF

kubectl apply -f radix-platform-config.yaml
rm radix-platform-config.yaml

echo "Done."

#######################################################################################
### Install Flux

echo ""
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" \
  CLUSTER_NAME="$CLUSTER_NAME" \
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
  --vault-name "$AZ_RESOURCE_KEYVAULT" \
  --name radix-cicd-canary-values \
  --file radix-cicd-canary-values.yaml

echo "clusterType: $CLUSTER_TYPE" >> radix-cicd-canary-values.yaml
echo "clusterFqdn: $CLUSTER_NAME.$AZ_RESOURCE_DNS" >> radix-cicd-canary-values.yaml

kubectl create ns radix-cicd-canary --dry-run --save-config -o yaml |
  kubectl apply -f -

kubectl create secret generic canary-secrets --namespace radix-cicd-canary \
  --from-file=./radix-cicd-canary-values.yaml \
  --dry-run -o yaml |
  kubectl apply -f -

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
  --vault-name "$AZ_RESOURCE_KEYVAULT" \
  --name "$AZ_VELERO_SECRET_NAME" \
  -f "$AZ_VELERO_SECRET_PAYLOAD_FILE"

kubectl create ns "$VELERO_NAMESPACE"
kubectl create secret generic cloud-credentials --namespace "$VELERO_NAMESPACE" \
  --from-env-file="$AZ_VELERO_SECRET_PAYLOAD_FILE" \
  --dry-run -o yaml |
  kubectl apply -f -

rm "$AZ_VELERO_SECRET_PAYLOAD_FILE"

# Create the cluster specific blob container
AZ_VELERO_STORAGE_ACCOUNT_ID="radixvelero${RADIX_ENVIRONMENT}"

az storage container create -n "$CLUSTER_NAME" \
  --public-access off \
  --account-name "$AZ_VELERO_STORAGE_ACCOUNT_ID" \
  2>&1 >/dev/null

# Create configMap that will hold the cluster specific values that Flux will later use when it manages the deployment of Velero
cat <<EOF | kubectl apply -f -
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

if [[ "$RADIX_ENVIRONMENT" != "test" ]]; then
  echo "Notifying on Slack"
  helm upgrade --install radix-boot-notify \
    ../charts/slack-notification \
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

#######################################################################################
### END
###

echo "Install of base components is done!"
echo ""
