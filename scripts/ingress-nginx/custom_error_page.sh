#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create / update error page for radix

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Keep name short due to Azure weirdness. Ex: "test-2", "weekly-93".

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./custom_error_page.sh

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash kubelogin 2>/dev/null || {
    echo -e "\nERROR: kubelogin not found in PATH. Exiting... " >&2
    exit 1
}

printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

if [[ -z "${RADIX_ZONE_ENV}" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "${RADIX_ZONE_ENV}" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=${RADIX_ZONE_ENV} is invalid, the file does not exist." >&2
        exit 1
    fi
    source "${RADIX_ZONE_ENV}"
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Resolve dependencies on other scripts
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ERROR_PAGE_PATH="${WORKDIR_PATH}/${RADIX_ERROR_PAGE}"
if ! [[ -e "${ERROR_PAGE_PATH}" ]]; then
    # Print to stderror
    echo "ERROR: The ${RADIX_ERROR_PAGE} is not found in path ${ERROR_PAGE_PATH}" >&2
fi

#######################################################################################
### CLUSTER?
###

kubectl_context="$(kubectl config current-context)"

if [ "${kubectl_context}" = "${CLUSTER_NAME}" ] || [ "${kubectl_context}" = "${CLUSTER_NAME}" ]; then
    echo "kubectl is ready..."
else
    echo "ERROR: Please set your kubectl current-context to be ${CLUSTER_NAME}" >&2
    exit 1
fi

#######################################################################################
### Verify cluster access
###

verify_cluster_access

#######################################################################################
### Create configmap for ingress-nginx defaultbackend
###

ERROR_PAGE_CONTENT=$(cat "${ERROR_PAGE_PATH}")

printf "\nCreating ConfigMap for ingress-nginx defaultbackend... "
# metadata name has to match configMap name in equinor/radix-flux/clusters/development/overlay/third-party/ingress-nginx/ingress-nginx.yaml
cat <<EOF | kubectl apply -f - 2>&1 >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-error-page
  namespace: ingress-nginx
data:
  404: |
    $(echo ${ERROR_PAGE_CONTENT})
  503: |
    $(echo ${ERROR_PAGE_CONTENT})
EOF
printf "Done.\n"

printf "\nDone.\n"
