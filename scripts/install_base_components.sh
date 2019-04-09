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
#
# CREDENTIALS:
# The script expects the slack-token to be found as secret in keyvault.

# We don't use Helm to add extra resources any more. Instead we use three different methods:
# For resources that don't need any change: yaml file in manifests/ directory
# Resources that need non-secret customizations: inline the resource in this script and use environment variables
# Resources that need secret values: store the entire yaml file in Azure KeyVault


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

OPERATOR_IMAGE_TAG="release-latest"

if [[ "$SUBSCRIPTION_ENVIRONMENT" != "prod" ]]; then
  OPERATOR_IMAGE_TAG="master-latest"
fi

if [[ -z "$FLUX_GITOPS_REPO" ]]; then
  FLUX_GITOPS_REPO="git@github.com:equinor/radix-flux.git"
fi

if [[ -z "$FLUX_GITOPS_BRANCH" ]]; then
  if [[ "$SUBSCRIPTION_ENVIRONMENT" == "prod" ]]; then
    FLUX_GITOPS_BRANCH="production"
  fi
  if [[ "$SUBSCRIPTION_ENVIRONMENT" == "dev" ]]; then
    FLUX_GITOPS_BRANCH="development"
  fi
fi

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
echo -e "OPERATOR_IMAGE_TAG      : $OPERATOR_IMAGE_TAG"
echo -e "FLUX_GITOPS_REPO        : $FLUX_GITOPS_REPO"
echo -e "FLUX_GITOPS_BRANCH      : $FLUX_GITOPS_BRANCH"
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

echo "Waiting 10 seconds for cert-manager to create certificate secrets before annotating them..."
sleep 10s

kubectl annotate Secret app-wildcard-tls-cert kubed.appscode.com/sync="app-wildcard-sync=app-wildcard-tls-cert"
kubectl annotate Secret cluster-wildcard-tls-cert kubed.appscode.com/sync="cluster-wildcard-sync=cluster-wildcard-tls-cert"


#######################################################################################
### Install nginx-ingress:
###

echo "Installing nginx-ingress"
helm upgrade --install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true --set controller.stats.enabled=true --set controller.metrics.enabled=true --set controller.service.externalTrafficPolicy=Local --set controller.metrics.serviceMonitor.enabled=true


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

helm upgrade --install external-dns stable/external-dns --set rbac.create=true --set interval=10s --set txtOwnerId=$CLUSTER_NAME --set provider=azure --set azure.secretName=external-dns-azure-secret --set domainFilters[0]=$DNS_ZONE

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
### Install humio
###

echo "Installing humio"

az keyvault secret download \
    --vault-name $VAULT_NAME \
    --name humio-values \
    --file humio-values.yaml

helm upgrade --install humio \
    "$HELM_REPO"/humio \
    --set ingress.clusterFQDN=$CLUSTER_NAME.$DNS_ZONE \
    --set ingress.tlsSecretName=cluster-wildcard-tls-cert \
    --set resources.limits.cpu=4 \
    --set resources.limits.memory=16000Mi \
    --set resources.requests.cpu=0.5 \
    --set resources.requests.memory=2000Mi \
    -f humio-values.yaml

rm -f humio-values.yaml


#######################################################################################
# TODO Remove radix-operator when Flux is up and running
### Install radix-operator
###

# echo "Installing radix-operator"

# az keyvault secret download \
#     --vault-name $VAULT_NAME \
#     --name radix-operator-values \
#     --file radix-operator-values.yaml

# helm upgrade --install radix-operator \
#     "$HELM_REPO"/radix-operator \
#     --set dnsZone="$DNS_ZONE" \
#     --set appAliasBaseURL="$APP_ALIAS_BASE_URL" \
#     --set prometheusName="$PROMETHEUS_NAME" \
#     --set imageRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
#     --set clusterName="$CLUSTER_NAME" \
#     --set image.tag="$OPERATOR_IMAGE_TAG" \
#     --set clusterType="$CLUSTER_TYPE" \
#     -f radix-operator-values.yaml


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
   --set registry.acr.enabled=true \
   weaveworks/flux > /dev/null

echo -e ""
echo -e ""
echo -e "A Flux service has been provisioned in the cluster to follow the GitOps way of thinking."
echo -e "At startup Flux generates a SSH key that should be added to git repository."
echo -e ""
echo -e "Step 1: get flux ssh key"
echo -e " Wait for container to start before getting SSH-key with command:"
echo -e "$ kubectl logs deployment/flux | grep identity.pub | cut -d '\"' -f2"
echo -e ""
echo -e "Step 2: Add ssh key to config repo"
echo -e "Add deploy key that can READ and WRITE to config repo"
echo -e ""
echo -e " You can then show the Flux logs (Close with Ctrl+C)"
echo  -e"$ kubectl logs deployment/flux -f"


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
