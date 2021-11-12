#!/usr/bin/env bash

# PURPOSE
# Adds all Private IP Prefix IPs assigned to the Radix Zone to a secret in the web component of Radix Web Console.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" WEB_CONSOLE_NAMESPACE="radix-web-console-qa" ./update_web_secret_for_console.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" WEB_CONSOLE_NAMESPACE="radix-web-console-qa" ./update_web_secret_for_console.sh)
#

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)
#   WEB_COMPONENT           (Mandatory)
#   WEB_CONSOLE_NAMESPACE   (Mandatory)

EGRESS_IP_SECRET_NAME="ALL_EGRESS_IPS"

echo ""
echo "Updating \"$EGRESS_IP_SECRET_NAME\" secret for the radix web console"

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

if [[ -z "$WEB_COMPONENT" ]]; then
    echo "Please provide WEB_COMPONENT."
    exit 1
fi

if [[ -z "$WEB_CONSOLE_NAMESPACE" ]]; then
    echo "Please provide WEB_CONSOLE_NAMESPACE."
    exit 1
fi

function updateEgressIpsSecret() {

    # Get list of IPs of all Public IP Prefixes assigned to Cluster Type
    echo "Getting list of IPs from all Public IP Prefixes assigned to $CLUSTER_TYPE clusters..."
    IPPRE_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/common/providers/Microsoft.Network/publicIPPrefixes/$IPPRE_NAME"
    RADIX_CLUSTER_EGRESS_IPS="$(az network public-ip list --query "[?publicIpPrefix.id=='$IPPRE_ID'].ipAddress" --output json)"

    if [[ "$RADIX_CLUSTER_EGRESS_IPS" == "[]" ]]; then
        echo "ERROR: Found no IPs."
        return
    fi

    # Loop through list of IPs and create a comma separated string. 
    for ipaddress in $(echo $RADIX_CLUSTER_EGRESS_IPS | jq -cr '.[]')
    do
        if [[ -z $IP_LIST ]]; then
            IP_LIST=$(echo $ipaddress)
        else
            IP_LIST="$IP_LIST,$(echo $ipaddress)"
        fi
    done

    # Get name of secret for web component
    WEB_CONSOLE_WEB_SECRET_NAME=$(kubectl get secret -l radix-component="$WEB_COMPONENT" -n "$WEB_CONSOLE_NAMESPACE" -o=jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -z "$WEB_CONSOLE_WEB_SECRET_NAME" ]]; then
        echo "ERROR: Secret for web component not found."
        return
    fi

    # Populate a temporary file with the contents of the secret
    WEB_SECRET_ENV_FILE="web_secret.env"
    echo "REACT_APP_RADIX_CLUSTER_EGRESS_IPS=$IP_LIST" >>"$WEB_SECRET_ENV_FILE"

    # Update secret for web component in web console namespace
    kubectl create secret generic "$WEB_CONSOLE_WEB_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" \
        --from-env-file="$WEB_SECRET_ENV_FILE" \
        --dry-run=client -o yaml |
        kubectl apply -f -

    # Remove temporary file
    rm "$WEB_SECRET_ENV_FILE"

    echo "Web component secret updated with Public IP Prefix IPs."

    # Restart deployment for web component
    printf "Restarting web deployment..."
    kubectl rollout restart deployment -n $WEB_CONSOLE_NAMESPACE $WEB_COMPONENT
    printf " Done."
}

### MAIN
updateEgressIpsSecret
