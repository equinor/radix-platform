#!/bin/bash

# Example:
# RADIX_ALIAS_CONFIG_VARS_PATH=./alias_config_console.sh ./create_alias.sh

# INPUTS:
#   RADIX_ALIAS_CONFIG_VARS_PATH (Mandatory - path to file)

# Validate mandatory input
if [[ -z "$RADIX_ALIAS_CONFIG_VARS_PATH" ]]; then
    echo "Please provide RADIX_ALIAS_CONFIG_VARS_PATH. Value must be a path to a file."
    exit 1
fi

# Import variables
source ./"$RADIX_ALIAS_CONFIG_VARS_PATH"

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
echo -e "RADIX_HELM_REPO              : $RADIX_HELM_REPO"
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