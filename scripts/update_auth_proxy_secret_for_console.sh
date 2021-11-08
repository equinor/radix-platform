#!/usr/bin/env bash

# PURPOSE
# Configures the auth proxy for the cluster given the context.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="auth" WEB_CONSOLE_NAMESPACE="radix-web-console-prod" AUTH_PROXY_REPLY_PATH="/oauth2/callback" ./update_auth_proxy_secret_for_console.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="auth" WEB_CONSOLE_NAMESPACE="radix-web-console-prod" AUTH_PROXY_REPLY_PATH="/oauth2/callback" ./update_auth_proxy_secret_for_console.sh)
#

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)
#   CLUSTER_NAME            (Mandatory)
#   WEB_COMPONENT           (Mandatory)
#   AUTH_PROXY_COMPONENT    (Mandatory)
#   WEB_CONSOLE_NAMESPACE   (Mandatory)
#   AUTH_PROXY_REPLY_PATH   (Mandatory)

echo ""
echo "Updating auth-proxy secret for the radix web console"

# Validate mandatory input

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
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

if [[ -z "$WEB_COMPONENT" ]]; then
    echo "Please provide WEB_COMPONENT."
    exit 1
fi

if [[ -z "$AUTH_PROXY_COMPONENT" ]]; then
    echo "Please provide AUTH_PROXY_COMPONENT."
    exit 1
fi

if [[ -z "$WEB_CONSOLE_NAMESPACE" ]]; then
    echo "Please provide WEB_CONSOLE_NAMESPACE."
    exit 1
fi

if [[ -z "$AUTH_PROXY_REPLY_PATH" ]]; then
    echo "Please provide AUTH_PROXY_REPLY_PATH."
    exit 1
fi

function updateWebSecret() {
    echo "Update web component secret with Cluster IP(s)."

    WEB_CONSOLE_WEB_SECRET_NAME=$(kubectl get secret -l radix-component="$WEB_COMPONENT" -n "$WEB_CONSOLE_NAMESPACE" -o=jsonpath=‘{.items[0].metadata.name}’ | sed 's/‘/ /g;s/’/ /g' | tr -d '[:space:]')
    IPPRE_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/common/providers/Microsoft.Network/publicIPPrefixes/$IPPRE_NAME"
    
    # list of AVAILABLE public ips assigned to the Radix Zone
    echo "Getting list of public ips assigned to $CLUSTER_NAME..."
    ASSIGNED_IPS="$(az network public-ip list | jq '.[] | select(.publicIpPrefix.id=="'$IPPRE_ID'" and .ipConfiguration.resourceGroup=="MC_'$AZ_RESOURCE_GROUP_CLUSTERS'_'$CLUSTER_NAME'_'$AZ_INFRASTRUCTURE_REGION'")' | jq '.ipAddress' | jq -s '.')"

    if [[ "$ASSIGNED_IPS" == "[]" ]]; then
        echo "ERROR: Found no IPs assigned to the cluster."
        return
    fi

    # Loop through list of IPs and create a comma separated string. 
    for ippre in $(echo $ASSIGNED_IPS | jq -c '.[]')
    do
        if [[ -z $IP_LIST ]]; then
            IP_LIST=$(echo $ippre | jq -r '.')
        else
            IP_LIST="$IP_LIST,$(echo $ippre | jq -r '.')"
        fi
    done

    WEB_SECRET_ENV_FILE="web_secret.env"
    echo "REACT_APP_CLUSTER_IPS=$IP_LIST" >>"$WEB_SECRET_ENV_FILE"
    
    kubectl create secret generic "$WEB_CONSOLE_WEB_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" \
        --from-env-file="$WEB_SECRET_ENV_FILE" \
        --dry-run=client -o yaml |
        kubectl apply -f -

    echo "Web component secret updated with cluster IP(s)."

    printf "Restarting web deployment..."
    kubectl rollout restart deployment -n $WEB_CONSOLE_NAMESPACE $WEB_COMPONENT
    printf " Done."
    rm "$WEB_SECRET_ENV_FILE"
}

function updateAuthProxySecret() {
    az keyvault secret download \
        -f radix-web-console-client-secret.yaml \
        -n "$VAULT_CLIENT_SECRET_NAME" \
        --vault-name "$AZ_RESOURCE_KEYVAULT"

    WEB_CONSOLE_AUTH_SECRET_NAME=$(kubectl get secret -l radix-component="$AUTH_PROXY_COMPONENT" -n "$WEB_CONSOLE_NAMESPACE" -o=jsonpath=‘{.items[0].metadata.name}’ | sed 's/‘/ /g;s/’/ /g' | tr -d '[:space:]')
    OAUTH2_PROXY_CLIENT_SECRET=$(cat radix-web-console-client-secret.yaml)
    OAUTH2_PROXY_COOKIE_SECRET=$(python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(16)).decode())')
    HOST_NAME=$(kubectl get ing -n "$WEB_CONSOLE_NAMESPACE" "$AUTH_PROXY_COMPONENT$AUTH_INGRESS_SUFFIX" -o json | jq --raw-output .spec.rules[0].host)
    OAUTH2_PROXY_REDIRECT_URL="https://${HOST_NAME}${AUTH_PROXY_REPLY_PATH}"
    AUTH_SECRET_ENV_FILE="auth_secret.env"

    echo "OAUTH2_PROXY_CLIENT_ID=$OAUTH2_PROXY_CLIENT_ID" >>"$AUTH_SECRET_ENV_FILE"
    echo "OAUTH2_PROXY_CLIENT_SECRET=$OAUTH2_PROXY_CLIENT_SECRET" >>"$AUTH_SECRET_ENV_FILE"
    echo "OAUTH2_PROXY_COOKIE_SECRET=$OAUTH2_PROXY_COOKIE_SECRET" >>"$AUTH_SECRET_ENV_FILE"
    echo "OAUTH2_PROXY_REDIRECT_URL=$OAUTH2_PROXY_REDIRECT_URL" >>"$AUTH_SECRET_ENV_FILE"
    echo "OAUTH2_PROXY_SCOPE=$OAUTH2_PROXY_SCOPE" >>"$AUTH_SECRET_ENV_FILE"
    
    kubectl create secret generic "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" \
        --from-env-file="$AUTH_SECRET_ENV_FILE" \
        --dry-run=client -o yaml |
        kubectl apply -f -

    rm radix-web-console-client-secret.yaml
    rm "$AUTH_SECRET_ENV_FILE"

    echo "Auth proxy secret updated"

    printf "Restarting auth deployment..."
    kubectl rollout restart deployment -n $WEB_CONSOLE_NAMESPACE $AUTH_PROXY_COMPONENT
    printf " Done."
    echo ""
    echo "NOTE: Console is set up with redirect url $OAUTH2_PROXY_REDIRECT_URL. If this cluster will be"
    echo "the official cluster, using the custom aliases, you will need to manually modify the OAUTH2_PROXY_REDIRECT_URL"
    echo "in the secret to point to the custom alias"
}

### MAIN
updateWebSecret
updateAuthProxySecret
