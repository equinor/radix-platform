#!/bin/bash

# PRECONDITIONS
#
# It is assumed that:
# 1. cluster is installed using the cluster_install.sh script,
# 2. that the base components exists
# 3. that the current context points to the correct cluster
# 4. sha256sum should be installed
#
# PURPOSE
#
# The purpose of the shell script is to set up all radix
# components of the cluster
#
# To run this script from terminal:
# SUBSCRIPTION_ENVIRONMENT=aa CLUSTER_NAME=bb ./deploy_radix_apps.sh
#
# Input environment variables:
#   SUBSCRIPTION_ENVIRONMENT    (Mandatory. Example: prod|dev)
#   CLUSTER_NAME                (Mandatory. Example: prod42)
#   RESOURCE_GROUP              (Optional. Example: "clusters")
#   HELM_REPO                   (Optional. Example: radixprod|radixdev)
#   VAULT_NAME                  (Optional. Example: radix-vault-prod|radix-vault-dev|radix-boot-dev-vault)


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
if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="clusters"
fi

if [[ -z "$VAULT_NAME" ]]; then
    VAULT_NAME="radix-vault-$SUBSCRIPTION_ENVIRONMENT"
fi

if [[ -z "$HELM_REPO" ]]; then
    HELM_REPO="radix${SUBSCRIPTION_ENVIRONMENT}"
fi

echo -e ""
echo -e "Start deploy of radix apps using the following settings:"
echo -e "SUBSCRIPTION_ENVIRONMENT: $SUBSCRIPTION_ENVIRONMENT"
echo -e "CLUSTER_NAME            : $CLUSTER_NAME"
echo -e "VAULT_NAME              : $VAULT_NAME"
echo -e "RESOURCE_GROUP          : $RESOURCE_GROUP"
echo -e "HELM_REPO               : $HELM_REPO"
echo -e ""


# Init: Set up helm repo
az acr helm repo add --name "$HELM_REPO" && \
    helm repo update

# Connect kubectl so we have the correct context
az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$CLUSTER_NAME"

# Radix Webhook
# This must be done to support deployments of application on git push.
az keyvault secret download \
    -f radix-github-webhook-radixregistration-values.yaml \
    -n radix-github-webhook-radixregistration-values \
    --vault-name "$VAULT_NAME"

helm upgrade --install radix-github-webhook \
    -f radix-github-webhook-radixregistration-values.yaml \
    "$HELM_REPO"/radix-registration

rm radix-github-webhook-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-github-webhook-master \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-github-webhook" \
    --set cloneURL="git@github.com:equinor/radix-github-webhook.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

helm upgrade --install radix-pipeline-github-webhook-release \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-github-webhook" \
    --set cloneURL="git@github.com:equinor/radix-github-webhook.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

# Radix API
az keyvault secret download \
    -f radix-api-radixregistration-values.yaml \
    -n radix-api-radixregistration-values \
    --vault-name "$VAULT_NAME"

helm upgrade --install radix-api \
    -f radix-api-radixregistration-values.yaml \
    "$HELM_REPO"/radix-registration

rm radix-api-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-api-master \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-api" \
    --set cloneURL="git@github.com:equinor/radix-api.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`" \
    --set useCache="false"

helm upgrade --install radix-pipeline-api-release \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-api" \
    --set cloneURL="git@github.com:equinor/radix-api.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`" \
    --set useCache="false"

# Radix Canary app
az keyvault secret download \
    -f radix-canary-radixregistration-values.yaml \
    -n radix-canary-radixregistration-values \
    --vault-name "$VAULT_NAME"

helm upgrade --install radix-canary \
    -f radix-canary-radixregistration-values.yaml \
    "$HELM_REPO"/radix-registration

rm radix-canary-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-canary-master \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-canary-golang" \
    --set cloneURL="git@github.com:equinor/radix-canary-golang.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

helm upgrade --install radix-pipeline-canary-release \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-canary-golang" \
    --set cloneURL="git@github.com:equinor/radix-canary-golang.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

# Radix Web Console
az keyvault secret download \
    -f radix-web-console-radixregistration-values.yaml \
    -n radix-web-console-radixregistration-values \
    --vault-name "$VAULT_NAME"

helm upgrade --install radix-web-console \
    -f radix-web-console-radixregistration-values.yaml \
    "$HELM_REPO"/radix-registration

rm radix-web-console-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-web-console-master \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-web-console" \
    --set cloneURL="git@github.com:equinor/radix-web-console.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

helm upgrade --install radix-pipeline-web-console-release \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-web-console" \
    --set cloneURL="git@github.com:equinor/radix-web-console.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

# Only done manually, not to screw up prod-cluster
# Add cluster URL to Azure App to allow for AAD Oauth login:
# PS: This removes all existing reply-urls. So make sure to include any other live clusters as well. Currently we use app id a593a59c-8f76-490e-937b-a90779039a90 for Omnia Radix Web Console on Azure Dev Subscription.

# az ad app update --id a593a59c-8f76-490e-937b-a90779039a90 --reply-urls \
#    http://localhost:3000/auth-callback \
#    https://console.dev.radix.equinor.com/auth-callback \
#    https://web-radix-web-console-qa.weekly-48-c.dev.radix.equinor.com/auth-callback \
#    https://web-radix-web-console-prod.weekly-48-c.dev.radix.equinor.com/auth-callback \
#    https://web-radix-web-console-qa.weekly-49.dev.radix.equinor.com/auth-callback \
#    https://web-radix-web-console-prod.weekly-49.dev.radix.equinor.com/auth-callback \
#    https://web-radix-web-console-qa.weekly-50.dev.radix.equinor.com/auth-callback \
#    https://web-radix-web-console-prod.weekly-50.dev.radix.equinor.com/auth-callback
# Todo: Maybe we should have a unique app-registration for each cluster instead to avoid the above problem.
# Note to above: no, you should simply let the script read the reply-urls into a variable, add the new url to the variable and then update the app-registration.

# Public Web Site
az keyvault secret download \
    -f radix-public-site-values.yaml \
    -n radix-public-site-values \
    --vault-name "$VAULT_NAME"

helm upgrade --install radix-public-site \
    -f radix-public-site-values.yaml \
    "$HELM_REPO"/radix-registration

rm radix-public-site-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-public-site-master \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-platform" \
    --set cloneURL="git@github.com:equinor/radix-platform.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

helm upgrade --install radix-pipeline-public-site-release \
    "$HELM_REPO"/radix-pipeline-invocation \
    --version 1.0.9 \
    --set name="radix-platform" \
    --set cloneURL="git@github.com:equinor/radix-platform.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix${SUBSCRIPTION_ENVIRONMENT}.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

# Step 2.6 Redirect public endpoints
# To be done manually