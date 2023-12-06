#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix service principals & managed identity: create them and store credentials in az keyvault

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap radix service principals & managed identity... "

#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}
hash gh 2>/dev/null || {
    echo -e "\nERROR: gh (GitHub CLI) not found in PATH. Exiting... " >&2
    exit 1
}
printf "Done.\n"

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$WORKDIR_PATH/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi

LIB_MANAGED_IDENTITY_PATH="$WORKDIR_PATH/lib_managed_identity.sh"
if [[ ! -f "$LIB_MANAGED_IDENTITY_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_MANAGED_IDENTITY_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_MANAGED_IDENTITY_PATH"
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

exit_if_user_does_not_have_required_ad_role
check_for_ad_owner_role

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap radix service principals & managed identity will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                               : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION                   : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                        : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
echo -e "   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD   : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
if [[ "$RADIX_ENVIRONMENT" == "dev" ]]; then
    echo -e "   -  MI_GITHUB_MAINTENANCE                    : ${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}"
fi
echo -e "   -  RESOURCE-LOCK-OPERATOR                   : ${APP_REGISTRATION_RESOURCE_LOCK_OPERATOR}"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                          : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                                  : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

#######################################################################################
### Create service principal
###

create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER" "Provide read-only access to container registry"
create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD" "Provide push, pull, build in container registry"

#######################################################################################
### Create managed identity
###

create_github_maintenance_mi() {
    permission=(
        "Microsoft.Authorization/roleAssignments/write"
        "Microsoft.ContainerService/managedClusters/write"
        "Microsoft.Insights/dataCollectionRuleAssociations/write"
        "Microsoft.Insights/dataCollectionRules/read"
        "Microsoft.Insights/dataCollectionRules/write"
        "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action"
        "Microsoft.Network/dnszones/A/read"
        "Microsoft.Network/dnszones/A/write"
        "Microsoft.Network/publicIPAddresses/join/action"
        "Microsoft.Network/virtualNetworks/subnets/join/action"
        "Microsoft.OperationalInsights/workspaces/read"
        "Microsoft.OperationalInsights/workspaces/sharedKeys/action"
        "Microsoft.OperationalInsights/workspaces/sharedkeys/read"
        "Microsoft.OperationsManagement/solutions/read"
        "Microsoft.OperationsManagement/solutions/write"
    )
    permission_json=$(jq -c -n '$ARGS.positional' --args "${permission[@]}")

    scopes=(
        "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_CLUSTERS}"
        "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}"
        "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_LOGS}"
    )
    scopes_json=$(jq -c -n '$ARGS.positional' --args "${scopes[@]}")

    role_name="radix-maintenance"

    create-az-role "${role_name}" "Permission needed for cluster maintenance" "$permission_json" "$scopes_json"
    create_managed_identity "${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}"
    create_role_assignment_for_identity "${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}" "${AKS_COMMAND_RUNNER_ROLE_NAME}" "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_CLUSTERS}"
    create_role_assignment_for_identity "${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}" "${role_name}" "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_CLUSTERS}"
    create_role_assignment_for_identity "${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}" "${role_name}" "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}"
    create_role_assignment_for_identity "${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}" "${role_name}" "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_LOGS}"
    add-federated-gh-credentials "${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}" "radix-flux" "master" "maintenance-${RADIX_ENVIRONMENT}"

    MI_ID=$(az ad sp list --filter "displayname eq '${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}'" --query [].appId --output tsv)
    gh_federated_credentials "radix-flux" "${MI_ID}" "${AZ_SUBSCRIPTION_ID}" "maintenance-${RADIX_ENVIRONMENT}"
}

#######################################################################################
### Create OIDC
###

create_github_resource_lock_operator() {
    create_oidc_and_federated_credentials "$APP_REGISTRATION_RESOURCE_LOCK_OPERATOR" "${AZ_SUBSCRIPTION_ID}" "radix-platform" "lock-operations-${RADIX_ENVIRONMENT}"
    assign_role "$APP_REGISTRATION_RESOURCE_LOCK_OPERATOR" "Omnia Authorization Locks Operator" "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_CLUSTERS}"
    assign_role "$APP_REGISTRATION_RESOURCE_LOCK_OPERATOR" "Reader" "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.KeyVault/vaults/${AZ_RESOURCE_KEYVAULT}"
    set-kv-policy "$(az ad sp list --filter "displayname eq '$APP_REGISTRATION_RESOURCE_LOCK_OPERATOR'" | jq -r .[].id)" "get"
}

if [[ "$RADIX_ENVIRONMENT" == "dev" ]]; then
    create_oidc_and_federated_credentials "$APP_REGISTRATION_GITHUB_MAINTENANCE" "${AZ_SUBSCRIPTION_ID}" "radix-platform" "operations"
    create_github_maintenance_mi
fi

create_github_resource_lock_operator

#######################################################################################
### END
###

echo ""
echo "Bootstrap of radix service principals & managed identity done!"
