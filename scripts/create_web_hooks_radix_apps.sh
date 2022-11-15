#!/usr/bin/env bash

# PRECONDITIONS
#
# It is assumed that:
# 1. that you have setup a personal github access token (https://github.com/settings/tokens)
#    with admin:repo_hook scope and set up the environment 
#    variables:
#    GH_USERNAME=<github user name>
#    GITHUB_PAT_TOKEN=<token generated>

# Add webhooks
kubectl get ing --namespace radix-github-webhook-prod -w

# Webhook for the radix-github-webhook project
# When the build is finished and the webhook is running, get the address as well as the shared secret:
WEBHOOK_HOSTNAME=$(kubectl get ing --namespace radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-github-webhook -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/equinor/radix-github-webhook/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq

# PS: If you get a "message": "Not Found" you have probably not set the GH_USERNAME and GITHUB_PAT_TOKEN environment variables. See pre-requisites above.

# Webhook for the radix-api project
WEBHOOK_HOSTNAME=$(kubectl get ing --namespace radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-api -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/equinor/radix-api/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq

# Webhook for the radix-cost-allocation-api project
WEBHOOK_HOSTNAME=$(kubectl get ing --namespace radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-cost-allocation-api -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/equinor/radix-cost-allocation-api/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq

# Webhook for the radix-canary-golang project
WEBHOOK_HOSTNAME=$(kubectl get ing --namespace radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-canary-golang -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
https://api.github.com/repos/equinor/radix-canary-golang/hooks \
-d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
echo $RESPONSE | jq

RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE  == "development" ]]; then
  echo "Development cluster uses QA web-console"
  RADIX_WEB_CONSOLE_ENV="qa"
fi
# Webhook for the radix-web-console project
WEBHOOK_HOSTNAME=$(kubectl get ing --namespace radix-github-webhook-$RADIX_WEB_CONSOLE_ENV webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-web-console -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
https://api.github.com/repos/equinor/radix-web-console/hooks \
-d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
echo $RESPONSE | jq

# Webhook for the radix-platform project
WEBHOOK_HOSTNAME=$(kubectl get ing --namespace radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-platform -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/equinor/radix-platform/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq

# Webhook for the radix-servicenow-proxy project
WEBHOOK_HOSTNAME=$(kubectl get ing --namespace radix-github-webhook-prod webhook -o json| jq --raw-output .spec.rules[0].host)
SHARED_SECRET=$(kubectl get rr radix-servicenow-proxy -o json | jq .spec.sharedSecret)
echo "Using webhook hostname:" $WEBHOOK_HOSTNAME "and shared secret" $SHARED_SECRET

RESPONSE=$(curl -X POST -H "Content-Type: application/json" -u ${GH_USERNAME}:${GITHUB_PAT_TOKEN} \
    https://api.github.com/repos/equinor/radix-servicenow-proxy/hooks \
    -d '{"name":"web", "active": true, "config": { "url": "https://'${WEBHOOK_HOSTNAME}/events/github'", "content_type": "json", "secret": '"${SHARED_SECRET}"' }}') && \
    echo $RESPONSE | jq 