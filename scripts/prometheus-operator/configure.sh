#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap prometheus-operator in a radix cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./configure.sh

#######################################################################################
### KNOWN ISSUES
###

#######################################################################################
### START
###
echo ""
echo "Start configuration of Prometheus..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
  echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
  exit 1
}
hash kubectl 2>/dev/null || {
  echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
  exit 1
}
hash helm 2>/dev/null || {
  echo -e "\nERROR: helm not found in PATH. Exiting..." >&2
  exit 1
}
hash jq 2>/dev/null || {
  echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
  exit 1
}
hash htpasswd 2>/dev/null || {
  echo -e "\nERROR: htpasswd not found in PATH. Exiting..." >&2
  exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
  echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
  exit 1
else
  if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
    exit 1
  fi
  source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
  echo "ERROR: Please provide CLUSTER_NAME" >&2
  exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 0
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

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
# # 2) Generate a cookie secret using `python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(16)).decode())'`
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


#######################################################################################
### Install custom ingresses
###

# Install Prometheus Ingress with HTTP Basic Authentication

# To generate a new file: `htpasswd -c ./auth prometheus`
# This file MUST be named `auth` when creating the secret!
echo ""
echo "Create secret..."
htpasswd -cb auth prometheus "$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name prometheus-token | jq -r .value)"
kubectl create secret generic prometheus-htpasswd \
  --from-file auth --dry-run=client -o yaml |
  kubectl apply -f -
rm -f auth

CLUSTER_NAME_LOWER="$(echo "$CLUSTER_NAME" | awk '{print tolower($0)}')"

# Create a custom ingress for prometheus that adds HTTP Basic Auth
echo ""
echo "Creating \"prometheus-basic-auth\" ingress..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
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
  - host: prometheus.${CLUSTER_NAME_LOWER}.$AZ_RESOURCE_DNS
    http:
      paths:
      - backend:
          service:
            name: prometheus-operator-prometheus
            port:
              number: 9090
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - prometheus.${CLUSTER_NAME_LOWER}.$AZ_RESOURCE_DNS
    secretName: radix-wildcard-tls-cert
EOF

# Install Prometheus Ingress that maps to the OAuth2 Proxy sidecar (specified in flux chart)
echo "Creating \"prometheus-oauth2-auth\" ingress..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
  labels:
    app: prometheus
  name: prometheus-oauth2-auth
spec:
  rules:
  - host: prometheus-oauth2.${CLUSTER_NAME_LOWER}.$AZ_RESOURCE_DNS
    http:
      paths:
      - backend:
          service:
            name: prometheus-operator-prometheus
            port:
              number: 4180
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - prometheus-oauth2.${CLUSTER_NAME_LOWER}.$AZ_RESOURCE_DNS
    secretName: radix-wildcard-tls-cert
EOF
