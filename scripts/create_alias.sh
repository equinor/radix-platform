#!/bin/bash

# Example:
# CLUSTER_NAME=aa ./create_alias.sh
#
# Example: Configure Playground, use default settings
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_NAME="playground-1" IS_PLAYGROUND_CLUSTER="true" ./create_alias.sh
#
# INPUTS:
#   SUBSCRIPTION_ENVIRONMENT    (Mandatory. Example: prod|dev)
#   CLUSTER_NAME                (Mandatory. Example: prod42)
#   RADIX_ZONE_NAME             (Optional. Defaulted if omitted)
#   RADIX_APP_ENVIRONMENT       (Optional. Defaulted if omitted. ex: "prod", "qa", "test")
#   HELM_REPO                   (Optional. Defaulted if omitted)
#   RESOURCE_GROUP              (Optional. Example: "clusters")
#   IS_PLAYGROUND_CLUSTER       (Optional. Defaulted if omitted)

#######################################################################################
### Validate mandatory input
###

if [[ -z "$SUBSCRIPTION_ENVIRONMENT" ]]; then
    echo "Please provide SUBSCRIPTION_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="clusters"
fi

# Set default values for optional input
if [[ -z "$RADIX_ZONE_NAME" ]]; then
    RADIX_ZONE_NAME="radix.equinor.com"
fi

if [[ -z "$RADIX_APP_ENVIRONMENT" ]]; then
    RADIX_APP_ENVIRONMENT="prod"
fi

if [[ -z "$HELM_REPO" ]]; then
    HELM_REPO="radix${SUBSCRIPTION_ENVIRONMENT}"
fi

# Check for Azure login
echo "Checking Azure account information"

AZ_ACCOUNT=`az account list | jq ".[] | select(.isDefault == true)"`
echo -n "You are logged in to subscription "
echo -n $AZ_ACCOUNT | jq '.id'
echo -n "Which is named " 
echo -n $AZ_ACCOUNT | jq '.name'
echo -n "As user " 
echo -n $AZ_ACCOUNT | jq '.user.name'
echo ""

read -p "Is this correct? (Y/n) " correct_az_login
if [[ $correct_az_login =~ (N|n) ]]; then
  echo "Please use 'az login' command to login to the correct account. Quitting."
  exit 1
fi

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo ""
echo "Connecting kubectl..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then    
    # Send message to stderr
    echo -e "Error: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 0        
fi

if [ "$IS_PLAYGROUND_CLUSTER" = "true" ]; then
    RADIX_ZONE_NAME="playground.$RADIX_ZONE_NAME"
fi

for filename in alias_config/*.sh; do
    [ -e "$filename" ] || continue
    
    # Import variables
    source ./"$filename"

    RADIX_APP_ALIAS_URL="$RADIX_APP_ALIAS_NAME.$RADIX_ZONE_NAME"

    # Show what we got before starting on the The Great Work
    echo -e ""
    echo -e "Start creating alias using the following settings:"
    echo -e ""
    echo -e "RADIX_ZONE_NAME              : $RADIX_ZONE_NAME"
    echo -e "RADIX_APP_CNAME              : $RADIX_APP_CNAME"
    echo -e "RADIX_APP_ALIAS_NAME         : $RADIX_APP_ALIAS_NAME"
    echo -e "RADIX_APP_ALIAS_URL          : $RADIX_APP_ALIAS_URL"
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
    helm upgrade --install radix-ingress-"$RADIX_APP_ALIAS_NAME" "$HELM_REPO"/ingress \
        --version 1.0.3 \
        --set aliasUrl="$RADIX_APP_ALIAS_URL" \
        --set application="$RADIX_APP_NAME" \
        --set applicationEnv="$RADIX_APP_ENVIRONMENT" \
        --set component="$RADIX_APP_COMPONENT" \
        --set componentPort="$RADIX_APP_COMPONENT_PORT" \
        --set enableAutoTLS=true
        
done