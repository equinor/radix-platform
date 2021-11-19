#!/usr/bin/env bash

# PURPOSE
# Adds all Private IP Prefix IPs assigned to the Radix Zone to a secret in the web component of Radix Web Console.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" WEB_CONSOLE_NAMESPACE="radix-web-console-qa" ./update_egress_ips_web_secret_for_console.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env WEB_COMPONENT="web" WEB_CONSOLE_NAMESPACE="radix-web-console-qa" ./update_egress_ips_web_secret_for_console.sh)
#

# INPUTS:
#   RADIX_ZONE_ENV          (Mandatory)
#   WEB_COMPONENT           (Mandatory)
#   WEB_CONSOLE_NAMESPACE   (Mandatory)

ENV_VAR_CONFIGMAP_NAME="CLUSTER_TYPE_EGRESS_IPS"

echo ""
echo "Updating \"$ENV_VAR_CONFIGMAP_NAME\" secret for the radix web console"

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

function updateEgressIpsEnvVars() {
    # Get list of IPs for all Public IP Prefixes assigned to Cluster Type
    echo "Getting list of IPs from all Public IP Prefixes assigned to $CLUSTER_TYPE clusters..."
    IPPRE_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/common/providers/Microsoft.Network/publicIPPrefixes/$IPPRE_NAME"
    RADIX_CLUSTER_EGRESS_IPS="$(az network public-ip list --query "[?publicIpPrefix.id=='$IPPRE_ID'].ipAddress" --output json)"

    if [[ "$RADIX_CLUSTER_EGRESS_IPS" == "[]" ]]; then
        echo "ERROR: Found no IPs assigned to the cluster."
        return
    fi

    # Loop through list of IPs and create a comma separated string. 
    for ippre in $(echo $RADIX_CLUSTER_EGRESS_IPS | jq -c '.[]')
    do
        if [[ -z $IP_LIST ]]; then
            IP_LIST=$(echo $ippre | jq -r '.')
        else
            IP_LIST="$IP_LIST,$(echo $ippre | jq -r '.')"
        fi
    done

    cat <<EOF >radix-flux-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-vars-${WEB_COMPONENT}
  namespace: ${WEB_CONSOLE_NAMESPACE}
data:
  ${ENV_VAR_CONFIGMAP_NAME}: "${IP_LIST}"
EOF

    kubectl apply -f radix-flux-config.yaml
    rm radix-flux-config.yaml

    echo "Web component env variable updated with Public IP Prefix IPs."

    # Restart deployment for web component
    printf "Restarting web deployment..."
    kubectl rollout restart deployment -n $WEB_CONSOLE_NAMESPACE $WEB_COMPONENT
    printf " Done."
}

### MAIN
updateEgressIpsEnvVars
