#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Upgrade Kubernetes Cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93".

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 ./upgradeKubernetes.sh

#######################################################################################
### START
###

echo ""
echo "Start Upgrade Kubernetes Cluster..."

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
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version ${AZ_CLI}) -lt $(version "${MIN_AZ_CLI}") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version ${AZ_CLI}.${normal}\n"
    exit 1
fi

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

# Read the cluster config that correnspond to selected environment in the zone config.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${CLUSTER_TYPE}.env"

# Optional inputs

if [[ -z "${USER_PROMPT}" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

#######################################################################################
### Upgrade cluster
###

fmt="%-8s%-33s%-12s\n"
fmt2="%-24s%-33s%-12s\n"

# Exit if source cluster does not exist
echo ""
echo "Verifying cluster existence..."
get_credentials "${AZ_RESOURCE_GROUP_CLUSTERS}" "${CLUSTER_NAME}" || {
    printf "${red}ERROR: Cluster \"%s\" not found.${normal}\n" "${CLUSTER_NAME}" >&2
    exit 1
}
echo ""

powerState="$(
    az aks show \
        --name "${CLUSTER_NAME}" \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --query "powerState" \
        --output "tsv"
)"

if [[ $powerState != "Running" ]]; then
    printf "${red}ERROR: %s is not in running state.${normal}\n" "${CLUSTER_NAME}"
    exit 1
fi

clusterNodepools="$(
    az aks nodepool list \
        --cluster-name "${CLUSTER_NAME}" \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --output json |
        jq '[.[] | {name: .name, mode: .mode, orchestratorVersion: .orchestratorVersion, vmSize: .vmSize}]'
)"

controlPlaneProfile="$(
    az aks get-upgrades \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --name "${CLUSTER_NAME}" \
        --query "controlPlaneProfile" \
        --output json
)"

controlPlaneVersion="$(jq -r .kubernetesVersion <<<"${controlPlaneProfile}")"

upgradeControlPlane=false

while true; do
    read -r -p "Check for new control plane version?: (Y/n) " yn
    case $yn in
    [Yy]*)
        upgradeControlPlane=true
        break
        ;;
    [Nn]*)
        echo ""
        echo "Skipping new control plane version check.."
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

if [[ "${upgradeControlPlane}" == true ]]; then
    mapfile -t controlPlaneUpgrades < <(jq -r '.upgrades[] | .kubernetesVersion' <<<"${controlPlaneProfile}")

    echo -e ""
    echo -e "Current Control Plane Profile in \"${CLUSTER_NAME}\""
    echo -e ""
    echo -e "   >  Current:"
    echo -e "   ------------------------------------------------------------------"
    echo -e "   -  KUBERNETES VERSION               : ${controlPlaneVersion}"
    echo -e "   -  OS TYPE                          : $(jq -r .osType <<<"${controlPlaneProfile}")"
    echo -e ""
    echo -e "   >  Available Versions:"
    echo -e "   ------------------------------------------------------------------"
    printf "${fmt}" "   #" "Version"
    for index in "${!controlPlaneUpgrades[@]}"; do
        printf "${fmt}" "   ${index}" "${controlPlaneUpgrades[$index]}"
    done
    echo -e ""
    echo ""

    while [ -z "${selectedControlPlaneVersionIndex}" ]; do
        read -r -p "Enter number of desired version: " selectedControlPlaneVersionIndex
    done

    selectedControlPlaneVersion="${controlPlaneUpgrades[$selectedControlPlaneVersionIndex]}"

    echo -e ""
    echo -e "Control Plane Upgrade will use the following configuration:"
    echo -e ""
    echo -e "   > WHERE:"
    echo -e "   ------------------------------------------------------------------"
    echo -e "   -  RADIX_ZONE                       : ${RADIX_ZONE}"
    echo -e "   -  AZ_RADIX_ZONE_LOCATION           : ${AZ_RADIX_ZONE_LOCATION}"
    echo -e "   -  RADIX_ENVIRONMENT                : ${RADIX_ENVIRONMENT}"
    echo -e ""
    echo -e "   > WHAT:"
    echo -e "   -------------------------------------------------------------------"
    echo -e "   -  CLUSTER_NAME                     : ${CLUSTER_NAME}"
    echo -e "   -  CURRENT CONTROL PLANE VERSION    : $(jq -r .kubernetesVersion <<<"${controlPlaneProfile}")"
    echo -e "   -  NEW CONTROL PLANE VERSION        : ${selectedControlPlaneVersion}"
    echo -e ""
    echo -e "   > WHO:"
    echo -e "   -------------------------------------------------------------------"
    echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name --output tsv)"
    echo -e "   -  AZ_USER                          : $(az account show --query user.name --output tsv)"
    echo -e ""
    echo ""

    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case ${yn} in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

    printf "Upgrading Control Plane in %s to %s" "${CLUSTER_NAME}" "${selectedControlPlaneVersion}... "
    az aks upgrade \
        --kubernetes-version "${selectedControlPlaneVersion}" \
        --name "${CLUSTER_NAME}" \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --control-plane-only \
        --yes \
        --only-show-errors
    printf "Done\n"
    controlPlaneVersion="${selectedControlPlaneVersion}"
fi

upgradeNodePools=false

while true; do
    read -r -p "Check for new node pool version? (Y/n) " yn
    case ${yn} in
    [Yy]*)
        upgradeNodePools=true
        break
        ;;
    [Nn]*)
        echo ""
        echo "Quitting."
        exit 0
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

if [[ "${upgradeNodePools}" == true ]]; then
    upgradableNodePools="[]"

    while read -r i; do
        version=$(jq -r .orchestratorVersion <<<"${i}")
        if [[ $(version "${version}") -lt $(version "${controlPlaneVersion}") ]]; then
            upgradableNodePools="$(
                jq '. += ['"${i}"']' <<<"${upgradableNodePools}"
            )"
        fi
    done < <(echo "${clusterNodepools}" | jq -c '.[]')

    if [[ $(jq '. | length' <<<"${upgradableNodePools}") -gt 0 ]]; then
        echo -e ""
        echo -e "Current Node Pools in \"${CLUSTER_NAME}\""
        echo -e ""
        echo -e "   >  Up to date Node Pools:"
        echo -e "   ------------------------------------------------------------------"
        printf "${fmt2}" "   -  Name" "Version" "mode"
        while read -r i; do
            name=$(jq -r .name <<<"${i}")
            version=$(jq -r .orchestratorVersion <<<"${i}")
            mode=$(jq -r .mode <<<"${i}")
            if [[ $(version "${version}") -ge $(version "${controlPlaneVersion}") ]]; then
                printf "${fmt2}" "   -  ${name}" "${version}" "${mode}"
            fi
        done < <(echo "${clusterNodepools}" | jq -c '.[]')
        echo -e ""
        echo -e "   >  Outdated Node Pools:"
        echo -e "   ------------------------------------------------------------------"
        printf "${fmt2}" "   -  Name" "Version" "mode"
        while read -r i; do
            name=$(jq -r .name <<<"${i}")
            version=$(jq -r .orchestratorVersion <<<"${i}")
            mode=$(jq -r .mode <<<"${i}")
            printf "${fmt2}" "   -  ${name}" "${version}" "${mode}"
        done < <(echo "${upgradableNodePools}" | jq -c '.[]')
        echo -e ""
        echo ""

        while true; do
            read -r -p "Upgrade outdated Node pools? (Y/n) " yn
            case ${yn} in
            [Yy]*) break ;;
            [Nn]*)
                echo ""
                echo "Quitting."
                exit 0
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done

        echo -e ""
        echo -e "Node Pool Upgrade will use the following configuration:"
        echo -e ""
        echo -e "   > WHERE:"
        echo -e "   ------------------------------------------------------------------"
        echo -e "   -  RADIX_ZONE                       : ${RADIX_ZONE}"
        echo -e "   -  AZ_RADIX_ZONE_LOCATION           : ${AZ_RADIX_ZONE_LOCATION}"
        echo -e "   -  RADIX_ENVIRONMENT                : ${RADIX_ENVIRONMENT}"
        echo -e "   -  CLUSTER_NAME                     : ${CLUSTER_NAME}"
        echo -e ""
        echo -e "   > WHAT:"
        echo -e "   -------------------------------------------------------------------"
        printf "${fmt2}" "   -  Name" "Old version" "New version"
        while read -r i; do
            name=$(jq -r .name <<<"${i}")
            version=$(jq -r .orchestratorVersion <<<"${i}")
            printf "${fmt2}" "   -  ${name}" "${version}" "${controlPlaneVersion}"
        done < <(echo "${upgradableNodePools}" | jq -c '.[]')
        echo -e ""
        echo -e "   > WHO:"
        echo -e "   -------------------------------------------------------------------"
        echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name --output tsv)"
        echo -e "   -  AZ_USER                          : $(az account show --query user.name --output tsv)"
        echo -e ""
        echo ""

        while true; do
            read -r -p "Is this correct? (Y/n) " yn
            case ${yn} in
            [Yy]*) break ;;
            [Nn]*)
                echo ""
                echo "Quitting."
                exit 0
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done

        while read -r i; do
            name=$(jq -r .name <<<"${i}")
            printf "Upgrading %s to %s" "${name}" "${controlPlaneVersion}... "
            az aks nodepool upgrade \
                --kubernetes-version "${controlPlaneVersion}" \
                --cluster-name "${CLUSTER_NAME}" \
                --name "${name}" \
                --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
                --only-show-errors
            printf "Done.\n"
        done < <(echo "${upgradableNodePools}" | jq -c '.[]')

    else
        echo "All Node Pools are up to date."
    fi
fi
