#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap requirements for radix-cost-allocation in a Radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV               : Path to *.env file
# - CLUSTER_NAME                 : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT                  : Is human interaction required to run script? true/false. Default is true.
# - REGENERATE_SQL_PASSWORD      : Should existing password for SQL login be regenerated and stored in KV? true/false. default is false

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap_collector.sh

# Generate and store new SQL user password - new password is stored in KV and updated for SQL user
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" REGENERATE_SQL_PASSWORD=true ./bootstrap_collector.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of radix-cost-allocation... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}
hash flux 2>/dev/null || {
    echo -e "\nERROR: flux not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
hash sqlcmd 2>/dev/null || {
    echo -e "\nERROR: sqlcmd not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Set default values for optional input
###

USER_PROMPT=${USER_PROMPT:=true}

REGENERATE_SQL_PASSWORD=${REGENERATE_SQL_PASSWORD:-false}

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

case $REGENERATE_SQL_PASSWORD in
    true|false) ;;
    *)
        echo 'ERROR: REGENERATE_SQL_PASSWORD must be true or false' >&2
        exit 1
        ;;
esac

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Load dependencies
LIB_AZURE_SQL_FIREWALL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../azure-sql/lib_firewall.sh"
if [[ ! -f "$LIB_AZURE_SQL_FIREWALL_PATH" ]]; then
   echo "ERROR: The dependency LIB_AZURE_SQL_FIREWALL_PATH=$LIB_AZURE_SQL_FIREWALL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_AZURE_SQL_FIREWALL_PATH"
fi

LIB_AZURE_SQL_SECURITY_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../azure-sql/lib_security.sh"
if [[ ! -f "$LIB_AZURE_SQL_SECURITY_PATH" ]]; then
   echo "ERROR: The dependency LIB_AZURE_SQL_SECURITY_PATH=$LIB_AZURE_SQL_SECURITY_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_AZURE_SQL_SECURITY_PATH"
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Ask user to verify inputs and az login
###

echo -e ""
echo -e "Bootstrap Radix Cost Allocation with the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT              : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  CLUSTER_NAME                      : $CLUSTER_NAME"
echo -e "   -  COST_ALLOCATION_SQL_SERVER_NAME   : $COST_ALLOCATION_SQL_SERVER_NAME"
echo -e "   -  COST_ALLOCATION_SQL_DATABASE_NAME : $COST_ALLOCATION_SQL_DATABASE_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  REGENERATE_SQL_PASSWORD           : $REGENERATE_SQL_PASSWORD"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                   : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                           : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

#######################################################################################
### CLUSTER?
###

printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME"
kubectl_context="$(kubectl config current-context)"
if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}" ]; then
    echo "kubectl is ready..."
else
    echo "Please set your kubectl current-context to be $CLUSTER_NAME"
    exit 1
fi

#######################################################################################
### Verify cluster access
###
verify_cluster_access

echo "Generate password for Radix Cost Allocation Writer SQL user and store in KV"

generate_password_and_store $AZ_RESOURCE_KEYVAULT $KV_SECRET_COST_ALLOCATION_DB_WRITER $REGENERATE_SQL_PASSWORD || exit

# Create/update SQL user and roles
COLLECTOR_SQL_PASSWORD=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name $KV_SECRET_COST_ALLOCATION_DB_WRITER | jq -r .value)
ADMIN_SQL_PASSWORD=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name $KV_SECRET_COST_ALLOCATION_SQL_ADMIN | jq -r .value) 

if [[ -z $ADMIN_SQL_PASSWORD ]]; then
    printf "ERROR: SQL admin password not set"
    exit 1
fi

echo "Whitelist IP in firewall rule for SQL Server"
whitelistRuleName="ClientIpAddress_$(date +%Y%m%d%H%M%S)"

add_local_computer_sql_firewall_rule \
    $COST_ALLOCATION_SQL_SERVER_NAME \
    $AZ_RESOURCE_GROUP_COST_ALLOCATION_SQL \
    $whitelistRuleName \
    || exit

echo "Creating/updating SQL user for Radix Cost Allocation"
create_or_update_sql_user \
    $COST_ALLOCATION_SQL_SERVER_FQDN \
    $COST_ALLOCATION_SQL_ADMIN_LOGIN \
    $ADMIN_SQL_PASSWORD \
    $COST_ALLOCATION_SQL_DATABASE_NAME \
    $COST_ALLOCATION_SQL_COLLECTOR_USER \
    $COLLECTOR_SQL_PASSWORD \
    "datawriter"

echo "Remove IP in firewall rule for SQL Server"
delete_sql_firewall_rule \
    $COST_ALLOCATION_SQL_SERVER_NAME \
    $AZ_RESOURCE_GROUP_COST_ALLOCATION_SQL \
    $whitelistRuleName \
    || exit


echo "Install Radix Cost Allocation resources for flux"

SQL_DB_PASSWORD=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name $KV_SECRET_COST_ALLOCATION_DB_WRITER | jq -r .value) ||
    { echo "ERROR: Could not get secret '${KV_SECRET_COST_ALLOCATION_DB_WRITER}' in '${AZ_RESOURCE_KEYVAULT}'." >&2; exit; }

echo "db:                                                                                                                           
  server: ${COST_ALLOCATION_SQL_SERVER_FQDN}
  database: ${COST_ALLOCATION_SQL_DATABASE_NAME}
  user: ${COST_ALLOCATION_SQL_COLLECTOR_USER}
  password: ${SQL_DB_PASSWORD}" > radix-cost-allocation-values.yaml

kubectl create ns radix-cost-allocation --dry-run=client --save-config -o yaml |
    kubectl apply -f -
    
kubectl create secret generic cost-db-secret --namespace radix-cost-allocation \
    --from-file=./radix-cost-allocation-values.yaml \
    --dry-run=client -o yaml |
    kubectl apply -f -

flux reconcile helmrelease --namespace radix-cost-allocation radix-cost-allocation
kubectl rollout restart deployment radix-cost-allocation --namespace radix-cost-allocation 

rm -f radix-cost-allocation-values.yaml

echo "Done."