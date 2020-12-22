#!/bin/bash

#######################################################################################
### PURPOSE
###

# Deploy all radix platform apps and make them ready for use

#######################################################################################
### PRECONDITIONS
###

# It is assumed that:
# 1. cluster is installed using the aks/bootstrap.sh script,
# 2. that the base components exists (install_base_components.sh has been run)
# 3. az, helm, jq, sha256sum should be installed

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./deploy_radix_apps.sh

#######################################################################################
### Support funcs
###

function assert_dep() {
    while [ -n "$1" ]; do
        command -v "$1" >/dev/null 2>&1 || {
            echo >&2 "Command \`$1\` is not installed. Aborting."
            exit 1
        }
        shift
    done
}

function wait_for_app_namespace() {
    local name # Input 1
    name="${1}"
    list_ns_command="kubectl get ns --selector="radix-app=$name" --output=name"
    echo "Waiting for app namespace..."

    while [[ $($list_ns_command) == "" ]]; do
        printf "."
        sleep 2s
    done
}

function wait_for_app_namespace_component_secret() {
    local namespace
    local component
    namespace="${1}"
    component="${2}"
    echo "Waiting for app $namespace $component secret..."
    while [[ $(kubectl get secrets -n "$namespace" | grep "$component"-) == "" ]]; do
        printf "."
        sleep 2s
    done
}

#######################################################################################
### Check for prerequisites binaries
###

assert_dep az helm jq sha256sum python3

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

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Deploy radix apps will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  Radix apps                       : all of them"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
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
### Deploy apps
###

# Init: Set up helm repo
helm repo update

# Connect kubectl so we have the correct context
az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME"
[[ "$(kubectl config current-context)" != "$CLUSTER_NAME-admin" ]] && exit 1

# Wait for operator to be deployed from flux
echo ""
echo "Waiting for radix-operator to be deployed by flux-operator so we can register radix apps"
while [[ "$(kubectl get deploy radix-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo "Radix operator is ready, registering apps... "

# Radix Webhook
# This must be done to support deployments of application on git push.
az keyvault secret download \
    -f radix-github-webhook-radixregistration-values.yaml \
    -n radix-github-webhook-radixregistration-values \
    --vault-name "$AZ_RESOURCE_KEYVAULT"

helm upgrade --install radix-github-webhook \
    -f radix-github-webhook-radixregistration-values.yaml \
    ../charts/radix-registration

rm radix-github-webhook-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
wait_for_app_namespace radix-github-webhook

helm upgrade --install radix-pipeline-github-webhook-master \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-github-webhook" \
    --set cloneURL="git@github.com:equinor/radix-github-webhook.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Wait a few seconds so that there is no conflics between jobs. I.e trying to create the RA object at the same time
sleep 4s

helm upgrade --install radix-pipeline-github-webhook-release \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-github-webhook" \
    --set cloneURL="git@github.com:equinor/radix-github-webhook.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Radix API
az keyvault secret download \
    -f radix-api-radixregistration-values.yaml \
    -n radix-api-radixregistration-values \
    --vault-name "$AZ_RESOURCE_KEYVAULT"

helm upgrade --install radix-api \
    -f radix-api-radixregistration-values.yaml \
    ../charts/radix-registration

rm radix-api-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
wait_for_app_namespace "radix-api"

helm upgrade --install radix-pipeline-api-master \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-api" \
    --set cloneURL="git@github.com:equinor/radix-api.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Wait a few seconds so that there is no conflics between jobs. I.e trying to create the RA object at the same time
sleep 4s

helm upgrade --install radix-pipeline-api-release \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-api" \
    --set cloneURL="git@github.com:equinor/radix-api.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Radix Cost Allocation API
az keyvault secret download \
    -f radix-cost-allocation-api-radixregistration-values.yaml \
    -n radix-cost-allocation-api-radixregistration-values \
    --vault-name "$AZ_RESOURCE_KEYVAULT"

helm upgrade --install radix-cost-allocation-api \
    -f radix-cost-allocation-api-radixregistration-values.yaml \
    ../charts/radix-registration

rm radix-cost-allocation-api-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
wait_for_app_namespace "radix-cost-allocation-api"

helm upgrade --install radix-cost-allocation-api-master \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-cost-allocation-api" \
    --set cloneURL="git@github.com:equinor/radix-cost-allocation-api.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Wait a few seconds so that there is no conflicts between jobs. I.e trying to create the RA object at the same time
sleep 4s

helm upgrade --install radix-cost-allocation-api-release \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-cost-allocation-api" \
    --set cloneURL="git@github.com:equinor/radix-cost-allocation-api.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Radix Canary app
az keyvault secret download \
    -f radix-canary-radixregistration-values.yaml \
    -n radix-canary-radixregistration-values \
    --vault-name "$AZ_RESOURCE_KEYVAULT"

helm upgrade --install radix-canary \
    -f radix-canary-radixregistration-values.yaml \
    ../charts/radix-registration

rm radix-canary-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
wait_for_app_namespace "radix-canary-golang"

helm upgrade --install radix-pipeline-canary-master \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-canary-golang" \
    --set cloneURL="git@github.com:equinor/radix-canary-golang.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Wait a few seconds so that there is no conflics between jobs. I.e trying to create the RA object at the same time
sleep 4s

helm upgrade --install radix-pipeline-canary-release \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-canary-golang" \
    --set cloneURL="git@github.com:equinor/radix-canary-golang.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Radix Web Console
az keyvault secret download \
    -f radix-web-console-radixregistration-values.yaml \
    -n radix-web-console-radixregistration-values \
    --vault-name "$AZ_RESOURCE_KEYVAULT"

helm upgrade --install radix-web-console \
    -f radix-web-console-radixregistration-values.yaml \
    ../charts/radix-registration

rm radix-web-console-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
wait_for_app_namespace "radix-web-console"

helm upgrade --install radix-pipeline-web-console-master \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-web-console" \
    --set cloneURL="git@github.com:equinor/radix-web-console.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Wait a few seconds so that there is no conflicts between jobs. I.e trying to create the RA object at the same time
sleep 4s

helm upgrade --install radix-pipeline-web-console-release \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-web-console" \
    --set cloneURL="git@github.com:equinor/radix-web-console.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Public Web Site
az keyvault secret download \
    -f radix-public-site-values.yaml \
    -n radix-public-site-values \
    --vault-name "$AZ_RESOURCE_KEYVAULT"

helm upgrade --install radix-public-site \
    -f radix-public-site-values.yaml \
    ../charts/radix-registration

rm radix-public-site-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
wait_for_app_namespace "radix-platform"

helm upgrade --install radix-pipeline-public-site-master \
    ../charts/radix-pipeline-invocation \
    --version 1.0.12 \
    --set name="radix-platform" \
    --set cloneURL="git@github.com:equinor/radix-platform.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
    --set imageTag="$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')"

# Update replyUrl for web-console
AUTH_PROXY_COMPONENT="auth"
AUTH_PROXY_REPLY_PATH="/oauth2/callback"
WEB_CONSOLE_NAMESPACE="radix-web-console-prod"

echo ""
echo "Waiting for web-console ingress to be ready so we can add replyUrl to web console aad app..."
while [[ "$(kubectl get ing $AUTH_PROXY_COMPONENT -n "$WEB_CONSOLE_NAMESPACE" 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo "Ingress is ready, adding replyUrl... "

# The web console has an aad app per cluster type. This script does not know about cluster type, so we will have to go with subscription environment.
if [[ "$RADIX_ENVIRONMENT" == "dev" ]]; then
    (AAD_APP_NAME="Omnia Radix Web Console - Development Clusters" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./add_reply_url_for_cluster.sh)
    wait # wait for subshell to finish
    (AAD_APP_NAME="Omnia Radix Web Console - Playground Clusters" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./add_reply_url_for_cluster.sh)
    wait # wait for subshell to finish
fi
if [[ "$RADIX_ENVIRONMENT" == "prod" ]]; then
    (AAD_APP_NAME="Omnia Radix Web Console - Production Clusters" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./add_reply_url_for_cluster.sh)
    wait # wait for subshell to finish
fi

echo ""
echo "For the web console to work we need to apply the secrets for the auth proxy"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./update_auth_proxy_secret_for_console.sh)
wait # wait for subshell to finish

echo ""
echo "Waiting for radix-api ingress to be ready so that the web console can work properly..."
while [[ "$(kubectl get ing server -n radix-api-prod 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done

echo ""
echo "Waiting for radix-cost-allocation-api ingress to be ready so that the API can work properly..."
while [[ "$(kubectl get ing server -n radix-cost-allocation-api-prod 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done

echo ""
echo "For the cost allocation api to work we need to apply secrets"
wait_for_app_namespace_component_secret "radix-cost-allocation-api-qa" "server"
wait_for_app_namespace_component_secret "radix-cost-allocation-api-prod" "server"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" ./update_secret_for_cost_allocation_api.sh)
wait # wait for subshell to finish

echo ""
echo "Radix API-s ingress is ready, restarting web console... "
kubectl delete pods $(kubectl get pods -n "$WEB_CONSOLE_NAMESPACE" -o custom-columns=':metadata.name' --no-headers | grep web) -n "$WEB_CONSOLE_NAMESPACE"

echo ""
echo "Roses are red, violets are blue"
echo "the deployment of radix apps has come to an end"
echo "but maybe not so"
echo "for all the remaining tasks assigned to you"
echo ""
