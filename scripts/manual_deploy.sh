#!/bin/bash

# PRECONDITIONS
#
# It is assumed that:
# 1. cluster is installed using the cluster_install.sh script,
# 2. that the base components exists
# 3. that the current context points to the correct cluster
# 4. that you have setup a personal github access token (https://github.com/settings/tokens)
#    with admin:repo_hook scope and set up the environment 
#    variables:
#    GH_USERNAME=<github user name>
#    GITHUB_PAT_TOKEN=<token generated>
# 5. sha256sum should be installed
#
# PURPOSE
#
# The purpose of the shell script is to set up all radix
# components of the cluster
#
# To run this script from terminal:
# HELM_REPO=aa VAULT_NAME=bb ./manual_deploy.sh
#
# Input environment variables:
#   SUBSCRIPTION_ENVIRONMENT (e.g. prod|dev)
#   HELM_REPO (e.g. radixdev)
#   VAULT_NAME (e.g. radix-boot-dev-vault)

# Init: Set up helm repo
az acr helm repo add --name $HELM_REPO && \
    helm repo update

# Radix Webhook
# This must be done to support deployments of application on git push.
az keyvault secret download \
    -f radix-github-webhook-radixregistration-values.yaml \
    -n radix-github-webhook-radixregistration-values \
    --vault-name $VAULT_NAME

helm upgrade --install radix-github-webhook \
    -f radix-github-webhook-radixregistration-values.yaml \
    $HELM_REPO/radix-registration

rm radix-github-webhook-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-github-webhook-master \
    $HELM_REPO/radix-pipeline-invocation \
    --set name="radix-github-webhook" \
    --set cloneURL="git@github.com:Statoil/radix-github-webhook.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="master-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`" \
    --set useCache="false"

helm upgrade --install radix-pipeline-github-webhook-release \
    $HELM_REPO/radix-pipeline-invocation \
    --set name="radix-github-webhook" \
    --set cloneURL="git@github.com:Statoil/radix-github-webhook.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="master-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`" \
    --set useCache="false"

# Radix API
az keyvault secret download \
    -f radix-api-radixregistration-values.yaml \
    -n radix-api-radixregistration-values \
    --vault-name $VAULT_NAME

helm upgrade --install radix-api \
    -f radix-api-radixregistration-values.yaml \
    $HELM_REPO/radix-registration

rm radix-api-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-api-master \
    $HELM_REPO/radix-pipeline-invocation \
    --set name="radix-api" \
    --set cloneURL="git@github.com:Statoil/radix-api.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="master-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`" \
    --set useCache="false"

helm upgrade --install radix-pipeline-api-release \
    $HELM_REPO/radix-pipeline-invocation \
    --set name="radix-api" \
    --set cloneURL="git@github.com:Statoil/radix-api.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="master-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`" \
    --set useCache="false"

# Radix Canary app
az keyvault secret download \
    -f radix-canary-radixregistration-values.yaml \
    -n radix-canary-radixregistration-values \
    --vault-name $VAULT_NAME

helm upgrade --install radix-canary \
    -f radix-canary-radixregistration-values.yaml \
    $HELM_REPO/radix-registration

rm radix-canary-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-canary-master \
    $HELM_REPO/radix-pipeline-invocation \
    --set name="radix-canary-golang" \
    --set cloneURL="git@github.com:Statoil/radix-canary-golang.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="master-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

helm upgrade --install radix-pipeline-canary-release \
    $HELM_REPO/radix-pipeline-invocation \
    --set name="radix-canary-golang" \
    --set cloneURL="git@github.com:Statoil/radix-canary-golang.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

# Radix Web Console
az keyvault secret download \
    -f radix-web-console-radixregistration-values.yaml \
    -n radix-web-console-radixregistration-values \
    --vault-name $VAULT_NAME

helm upgrade --install radix-web-console \
    -f radix-web-console-radixregistration-values.yaml \
    $HELM_REPO/radix-registration

rm radix-web-console-radixregistration-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-web-console-master \
    $HELM_REPO/radix-pipeline-invocation \
    --version 1.0.4 \
    --set name="radix-web-console" \
    --set cloneURL="git@github.com:Statoil/radix-web-console.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

helm upgrade --install radix-pipeline-web-console-release \
    $HELM_REPO/radix-pipeline-invocation \
    --version 1.0.4 \
    --set name="radix-web-console" \
    --set cloneURL="git@github.com:Statoil/radix-web-console.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
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

# Public Web Site
az keyvault secret download \
    -f radix-public-site-values.yaml \
    -n radix-public-site-values \
    --vault-name $VAULT_NAME

helm upgrade --install radix-public-site \
    -f radix-public-site-values.yaml \
    $HELM_REPO/radix-registration

rm radix-public-site-values.yaml

# Wait a few seconds until radix-operator can process the RadixRegistration
sleep 3s

helm upgrade --install radix-pipeline-public-site-master \
    $HELM_REPO/radix-pipeline-invocation \
    --version 1.0.4 \
    --set name="radix-platform" \
    --set cloneURL="git@github.com:Statoil/radix-platform.git" \
    --set cloneBranch="master" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

helm upgrade --install radix-pipeline-public-site-release \
    $HELM_REPO/radix-pipeline-invocation \
    --version 1.0.4 \
    --set name="radix-platform" \
    --set cloneURL="git@github.com:Statoil/radix-platform.git" \
    --set cloneBranch="release" \
    --set pipelineImageTag="release-latest" \
    --set containerRegistry="radix$SUBSCRIPTION_ENVIRONMENT.azurecr.io" \
    --set imageTag="`date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]'`"

# Step 2.6 Redirect public endpoints
# To be done manually

# Add webhooks

# Wait for the build and deploy to finish and the ingress to appear, this might take a few minutes:
sleep 10m
kubectl get ing -n radix-github-webhook-prod -w

# Webhook for the radix-github-webhook project
# When the build is finished and the webhook is running, get the address as well as the shared secret:
WEBHOOK_HOSTNAME=$(kubectl get ing -n radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-github-webhook -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/Statoil/radix-github-webhook/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq

# PS: If you get a "message": "Not Found" you have probably not set the GH_USERNAME and GITHUB_PAT_TOKEN environment variables. See pre-requisites above.

# Webhook for the radix-api project
WEBHOOK_HOSTNAME=$(kubectl get ing -n radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-api -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/Statoil/radix-api/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq

# Webhook for the radix-canary-golang project
WEBHOOK_HOSTNAME=$(kubectl get ing -n radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-canary-golang -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
https://api.github.com/repos/Statoil/radix-canary-golang/hooks \
-d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
echo $RESPONSE | jq

# Webhook for the radix-web-console project
WEBHOOK_HOSTNAME=$(kubectl get ing -n radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-web-console -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
https://api.github.com/repos/Statoil/radix-web-console/hooks \
-d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
echo $RESPONSE | jq

# Webhook for the radix-platform project
WEBHOOK_HOSTNAME=$(kubectl get ing -n radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-platform -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/Statoil/radix-platform/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq