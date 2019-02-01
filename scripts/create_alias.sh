#!/bin/bash

# Example:
# CLUSTER_NAME=aa ./create_alias.sh

# INPUTS:
#   CLUSTER_NAME                (Mandatory. Example: prod42)
#   RADIX_ZONE_NAME             (Optional. Defaulted if omitted)
#   RADIX_APP_ENVIRONMENT       (Optional. Defaulted if omitted. ex: "prod", "qa", "test")
#   HELM_REPO                   (Optional. Defaulted if omitted)

# Validate mandatory input
if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

# Set default values for optional input
if [[ -z "$RADIX_ZONE_NAME" ]]; then
    RADIX_ZONE_NAME="radix.equinor.com"
fi

if [[ -z "$RADIX_APP_ENVIRONMENT" ]]; then
    RADIX_APP_ENVIRONMENT="prod"
fi

if [[ -z "$HELM_REPO" ]]; then
    HELM_REPO="radixprod"
fi

for filename in alias_config/*.sh; do
    [ -e "$filename" ] || continue
    
    # Import variables
    source ./"$filename"

    # Show what we got before starting on the The Great Work
    echo -e ""
    echo -e "Start creating alias using the following settings:"
    echo -e ""
    echo -e "RADIX_ZONE_NAME              : $RADIX_ZONE_NAME"
    echo -e "RADIX_APP_CNAME              : $RADIX_APP_CNAME"
    echo -e "RADIX_APP_ALIAS_NAME         : $RADIX_APP_ALIAS_NAME"
    echo -e "RADIX_APP_NAME               : $RADIX_APP_NAME"
    echo -e "RADIX_APP_ENVIRONMENT        : $RADIX_APP_ENVIRONMENT"
    echo -e "RADIX_APP_COMPONENT          : $RADIX_APP_COMPONENT"
    echo -e "RADIX_APP_COMPONENT_PORT     : $RADIX_APP_COMPONENT_PORT"
    echo -e "HELM_REPO                    : $HELM_REPO"
    echo -e ""

    # Create alias in the dns zone
    az network dns record-set cname set-record \
        --resource-group common \
        --zone-name "$RADIX_ZONE_NAME" \
        --record-set-name "$RADIX_APP_ALIAS_NAME" \
        --cname "$RADIX_APP_CNAME"

    # Create ingress object in the cluster
    helm upgrade --install radix-ingress-"$RADIX_APP_ALIAS_NAME" "$RADIX_HELM_REPO"/ingress \
        --version 1.0.3 \
        --set aliasUrl="$RADIX_APP_ALIAS_NAME.$RADIX_ZONE_NAME" \
        --set application="$RADIX_APP_NAME" \
        --set applicationEnv="$RADIX_APP_ENVIRONMENT" \
        --set component="$RADIX_APP_COMPONENT" \
        --set componentPort="$RADIX_APP_COMPONENT_PORT" \
        --set enableAutoTLS=true
done