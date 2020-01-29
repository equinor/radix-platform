#!/bin/bash

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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### KNOWN ISSUES
###

#######################################################################################
### START
###

echo "Bootstrap prometheus-operator..."

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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME" >&2
    exit 1
fi

# IKNU : 2020.01.09 : The following is needed becuase prometheus started failing installation
# In addition prometheusOperator.createCustomResource=false is set when installing chart
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.34/example/prometheus-operator-crd/alertmanager.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.34/example/prometheus-operator-crd/prometheus.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.34/example/prometheus-operator-crd/prometheusrule.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.34/example/prometheus-operator-crd/servicemonitor.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.34/example/prometheus-operator-crd/podmonitor.crd.yaml

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
    --version 8.3.2 \
    -f ./prometheus-operator-values.yaml \
    --set prometheus.prometheusSpec.serviceMonitorSelector.any=true \
    --set prometheusOperator.createCustomResource=false

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
    --patch "$(cat ./kubelet-service-monitor-patch.yaml)"
