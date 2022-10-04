#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create / update custom_error_pages for ingress-nginx

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Keep name short due to Azure weirdness. Ex: "test-2", "weekly-93".

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./custom_error_pages.sh

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

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.37.0"
if [ $(version ${AZ_CLI}) -lt $(version "${MIN_AZ_CLI}") ]; then
    printf ""${yel}"Due to the deprecation of Azure Active Directory (Azure AD) Graph in version "{$MIN_AZ_CLI}", please update your local installed version "${AZ_CLI}"${normal}\n"
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

# Required inputs

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

ERROR_PAGE="${WORKDIR_PATH}/error_page.html"
if ! [[ -e "${ERROR_PAGE}" ]]; then
    # Print to stderror
    echo "ERROR: The error_page.html is not found in path ${ERROR_PAGE}" >&2
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

ERROR_PAGE_CONTENT=$(cat "${ERROR_PAGE}")

printf "\nCreating custom_error_pages for ingress-nginx... "
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-error-pages
  namespace: ingress-nginx
data:
  503: |
    $(echo ${ERROR_PAGE_CONTENT})
EOF
printf "Done.\n"

printf "\nDone.\n"
