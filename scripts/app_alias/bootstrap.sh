#!/usr/bin/env bash


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
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2;  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nERROR: helm not found in PATH. Exiting..." >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nERROR: jq not found in PATH. Exiting..." >&2;  exit 1; }
printf "All is good."
echo ""


#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

LIB_DNS_SCRIPT="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/dns/lib_dns.sh"
if ! [[ -x "$LIB_DNS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The lib dns script is not found or it is not executable in path $LIB_DNS_SCRIPT" >&2
else
    source $LIB_DNS_SCRIPT
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
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo ""
fi

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo "Connecting kubectl..."   
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {    
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1        
}

#######################################################################################
### Bootstrap aliases
###

#helm repo update
CONFIG_DIR="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/app_alias/configs"

# Get cluster IP
cluster_ip=$(kubectl get secret --namespace "ingress-nginx" "ingress-nginx-raw-ip" -ojson | jq .data.rawIp --raw-output | base64 --decode)

set -f
a_records=('@' '*' '*.app')
# Create A records in the dns zone
# creating the "@"-record, i.e. e.g. dev.radix.equinor.com.
# creating wildcard record to match all FQDNs in active-cluster ingresses
# creating wildcard record to match all FQDNs in "app alias" ingresses
for record in ${a_records[@]}
do
  create-a-record "${record}" "$cluster_ip" "$AZ_RESOURCE_GROUP_COMMON" "$AZ_RESOURCE_DNS" "60" || {
      echo "ERROR: failed to create A record ${record}.${AZ_RESOURCE_DNS}" >&2
  }
done
set +f


# iterate over configs for selected Radix components and apply ingress objects with custom names
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

    # # Create ingress object in the cluster
    if [[ "$RADIX_APP_ALIAS_NAME" == "@" ]]; then
        HELM_NAME="radix-ingress-at"
    else
        HELM_NAME="radix-ingress-$RADIX_APP_ALIAS_NAME"
    fi

    chartPath="${RADIX_PLATFORM_REPOSITORY_PATH}/charts/ingress/"
    helm upgrade --install "$HELM_NAME" \
        "$chartPath" \
        --set aliasUrl="$RADIX_APP_ALIAS_URL" \
        --set appAliasName="$RADIX_APP_ALIAS_NAME" \
        --set application="$RADIX_APP_NAME" \
        --set namespace="$RADIX_NAMESPACE" \
        --set component="$RADIX_APP_COMPONENT" \
        --set componentPort="$RADIX_APP_COMPONENT_PORT" \
        --set authSecret="$RADIX_AUTH_SECRET"
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
