#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Create "user friendly" alias for the CNAME of an existing radix app.
# We do this by creating a custom ingress for each radix app in the target cluster.


#######################################################################################
### DEPENDENCIES
### 

# Each app alias must be defined as a config file in directory ./configs/


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
# - CLUSTER_NAME            : Ex: "test-2", "weekly-93"

# Optional:
# - RADIX_APP_ENVIRONMENT   : Defaulted if omitted. ex: "prod", "qa", "test"           
# - USER_PROMPT             : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
### 

# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap radix app aliases... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting...";  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting...";  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nError: helm not found in PATH. Exiting...";  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nError: jq not found in PATH. Exiting...";  exit 1; }
printf "All is good."
echo ""


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

if [[ -z "$RADIX_APP_ENVIRONMENT" ]]; then
    RADIX_APP_ENVIRONMENT="prod"
fi
if [[ $CLUSTER_TYPE  == "development" ]]; then
  echo "Development cluster uses QA environment"
  RADIX_APP_ENVIRONMENT="qa"
fi

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
echo -e "Bootstrap radix app aliases will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  RADIX_APP_ENVIRONMENT            : $RADIX_APP_ENVIRONMENT"
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
### Connect kubectl
###

# Exit if cluster does not exist
echo ""
echo "Connecting kubectl..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"  --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then    
    # Send message to stderr
    echo -e "Error: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1        
fi


#######################################################################################
### Bootstrap aliases
###

helm repo update
WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="${WORK_DIR}/configs"

for alias_config in "$CONFIG_DIR"/*.env; do
    [ -e "$alias_config" ] || continue
    
    # Import variables
    source "$alias_config"

    if [[ "$RADIX_APP_ALIAS_NAME" == "@" ]]; then
        RADIX_APP_ALIAS_URL="$AZ_RESOURCE_DNS"
    else
        RADIX_APP_ALIAS_URL="$RADIX_APP_ALIAS_NAME.$AZ_RESOURCE_DNS"
    fi

    if [[ -z "$RADIX_NAMESPACE" ]]; then
        RADIX_NAMESPACE="$RADIX_APP_NAME-$RADIX_APP_ENVIRONMENT"
    fi

    # Show what we got before starting on the The Great Work
    echo -e ""
    echo -e "   Processing alias \"${RADIX_APP_ALIAS_NAME}\" config:"
    echo -e ""
    echo -e "   - AZ_RESOURCE_DNS              : $AZ_RESOURCE_DNS"
    echo -e "   - RADIX_APP_CNAME              : $RADIX_APP_CNAME"
    echo -e "   - RADIX_APP_ALIAS_NAME         : $RADIX_APP_ALIAS_NAME"
    echo -e "   - RADIX_APP_ALIAS_URL          : $RADIX_APP_ALIAS_URL"
    echo -e "   - RADIX_APP_NAME               : $RADIX_APP_NAME"
    echo -e "   - RADIX_APP_ENVIRONMENT        : $RADIX_APP_ENVIRONMENT"
    echo -e "   - RADIX_NAMESPACE              : $RADIX_NAMESPACE"
    echo -e "   - RADIX_APP_COMPONENT          : $RADIX_APP_COMPONENT"
    echo -e "   - RADIX_APP_COMPONENT_PORT     : $RADIX_APP_COMPONENT_PORT"
    echo -e "   - RADIX_AUTH_SECRET            : $RADIX_AUTH_SECRET"

    echo -e ""
    printf "     Working..."

    # Get cluster IP
    CLUSTER_IP=$(dig +short public-site-radix-platform-prod.$CLUSTER_NAME.$AZ_RESOURCE_DNS)

    # Create alias in the dns zone
    if [[ "$RADIX_APP_ALIAS_NAME" == "@" ]]; then
        az network dns record-set a add-record \
            --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
            --zone-name "$AZ_RESOURCE_DNS" \
            --record-set-name "$RADIX_APP_ALIAS_NAME" \
            --ipv4-address "$CLUSTER_IP" \
            --if-none-match \
            --ttl 300 \
            2>&1 >/dev/null
        echo "ERROR OK - Marko"
    else
        az network dns record-set cname set-record \
            --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
            --zone-name "$AZ_RESOURCE_DNS" \
            --record-set-name "$RADIX_APP_ALIAS_NAME" \
            --cname "$RADIX_APP_CNAME" \
            --ttl 300 \
            2>&1 >/dev/null
    fi

    # # Create ingress object in the cluster
    if [[ "$RADIX_APP_ALIAS_NAME" == "@" ]]; then
        HELM_NAME="radix-ingress-at"
    else
        HELM_NAME="radix-ingress-$RADIX_APP_ALIAS_NAME"
    fi

    chartPath="$WORK_DIR/../../charts/ingress/"
    helm upgrade --install "$HELM_NAME" \
        "$chartPath" \
        --set aliasUrl="$RADIX_APP_ALIAS_URL" \
        --set appAliasName="$RADIX_APP_ALIAS_NAME" \
        --set application="$RADIX_APP_NAME" \
        --set namespace="$RADIX_NAMESPACE" \
        --set component="$RADIX_APP_COMPONENT" \
        --set componentPort="$RADIX_APP_COMPONENT_PORT" \
        --set authSecret="$RADIX_AUTH_SECRET" \
        --set enableAutoTLS=true \
        2>&1 >/dev/null

    printf "Done."
    echo ""
done

#######################################################################################
### END
###

echo ""
echo "Bootstrap of radix app aliases is done!"
echo ""