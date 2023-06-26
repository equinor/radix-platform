#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap github maintenace: create role and rolebinding for github managed identity

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap github maintenance... "

#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
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

LIB_SERVICE_PRINCIPAL_PATH="$RADIX_PLATFORM_REPOSITORY_PATH/scripts/service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi

LIB_MANAGED_IDENTITY_PATH="$RADIX_PLATFORM_REPOSITORY_PATH/scripts/service-principals-and-aad-apps/lib_managed_identity.sh"
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

### Start

printf "Creating role...\n"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: radix-github-maintenance
rules:
  - apiGroups: ['*']
    resources: ['pods']
    verbs: ['get', 'list']
  - apiGroups: ['*']
    resources: ['secrets']
    verbs: ['get', 'create', 'list', 'patch', 'update', 'delete']
  - apiGroups: ['apps']
    resources: ['deployments']
    verbs: ['get', 'patch']
  - apiGroups: ['apps']
    resources: ['deployments/scale']
    verbs: ['patch']
  - apiGroups: ['networking.k8s.io']
    resources: ['ingresses']
    verbs: ['get', 'create', 'delete']
  - apiGroups: ['kustomize.toolkit.fluxcd.io']
    resources: ['kustomizations']
    verbs: ['get', 'list', 'watch', 'patch']
EOF
printf "Done\n"

object_id=$(az identity show --name "${MI_GITHUB_MAINTENANCE}-${RADIX_ENVIRONMENT}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query principalId -o tsv) || {
    echo -e "ERROR: Could not retrieve object ID of MI ${MI_GITHUB_MAINTENANCE}." >&2
    exit 1
}

set-kv-policy "${object_id}" "get set"

namespaces=("default" "ingress-nginx" "radix-web-console-qa" "radix-cicd-canary" "flux-system" "radix-api-qa" "radix-canary-golang-qa" "radix-cost-allocation-api-qa" "radix-platform-qa" "radix-github-webhook-qa" "monitor")

for namespace in "${namespaces[@]}"; do
    printf "Creating rolebinding in %s...\n" "${namespace}"
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: radix-github-maintenance
  namespace: ${namespace}
subjects:
  - kind: User
    name: xx
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: radix-github-maintenance
  apiGroup: rbac.authorization.k8s.io
EOF
    printf "Done\n"

    printf "Patching rolebinding in %s... " "${namespace}"
    kubectl patch rolebindings.rbac.authorization.k8s.io "radix-github-maintenance" \
        --namespace "${namespace}" \
        --type strategic \
        --patch '{"subjects":[{"apiGroup":"rbac.authorization.k8s.io","kind":"User","name":"'${object_id}'"}]}' 2>&1 >/dev/null
    printf "Done\n"
done

echo ""
echo "Bootstrap of github maintenance done!"
