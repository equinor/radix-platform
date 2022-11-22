#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Deploy all radix platform apps and make them ready for use

#######################################################################################
### PRECONDITIONS
###

# It is assumed that:
# 1. cluster is installed using the aks/bootstrap.sh script,
# 2. that the base components exists (install_base_components.sh has been run)
# 3. az, jq, sha256sum, base64, date/gdate should be installed

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"
# - GITHUB_PAT          : GitHub Personal Access Token with 'repo', 'admin:repo_hook', 'admin:org_hook' and 'admin:org' scopes.

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Normal:
# RADIX_ZONE_ENV=../../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" GITHUB_PAT="" ./deploy_radix_apps.sh

# Skip creation of radixJobs and specify deploy key name:
# RADIX_ZONE_ENV=../../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" GITHUB_PAT="" CREATE_BUILD_DEPLOY_JOBS="false" DEPLOY_KEY_NAME="dev" ./deploy_radix_apps.sh

#######################################################################################
### Support funcs
###

function assert_dep() {
    while [ -n "$1" ]; do
        command -v "$1" >/dev/null 2>&1 || {
            echo >&2 "Command \`$1\` is not installed. Aborting."
            exit 1
        }
        shift
    done
}

# Function to ensure same functionality on linux and mac
function date () 
{ 
    if type -p gdate > /dev/null; then
        gdate "$@";
    else
        command date "$@";
    fi
}

function wait_for_app_namespace() {
    local name # Input 1
    name="${1}"
    list_ns_command="kubectl get ns --selector="radix-app=$name" --output=name"
    echo "Waiting for app namespace..."

    while [[ $($list_ns_command) == "" ]]; do
        printf "."
        sleep 2
    done
}

function wait_for_app_namespace_component_secret() {
    local namespace
    local component
    namespace="${1}"
    component="${2}"
    echo "Waiting for app $namespace $component secret..."
    while [[ $(kubectl get secrets -n "$namespace" | grep "$component"-) == "" ]]; do
        printf "."
        sleep 2
    done
}

function create_and_register_deploy_key_and_store_credentials() {
    # This function uses a GitHub Personal Access Token to check if there is a deploy key in the repo which has not expired.
    # If there is no deploy key, or it is due for renewal, a new deploy key will be created and added to the repo.
    # The credentials will be stored in a keyvault secret to be used when creating the radixRegistration and radixJob.

    local app_name          # Input 1
    local repo_name         # Input 2
    local repo_organization # Input 3
    local github_pat        # Input 4
    local ad_groups         # Input 5
    local shared_secret     # Input 6, optional
    local config_branch     # Input 7, optional
    local machine_user      # Input 8, optional
    local deploy_key_name   # Input 9, optional
    local configuration_item # Input 109, optional
    local template_path
    local check_key
    local private_key
    local public_key
    local key_fingerprint

    app_name="${1}"
    repo_name="${2}"
    repo_organization="${3}"
    github_pat="${4}"
    ad_groups="${5}"
    shared_secret="${6}"
    config_branch="${7:-master}"
    machine_user="${8:-false}"
    deploy_key_name="${9:-${RADIX_ZONE}-${RADIX_ENVIRONMENT}}"
    configuration_item="${10}"

    if [ -z "${app_name}" ] || [ -z "${repo_name}" ] || [ -z "${repo_organization}" ] || [ -z "${github_pat}" ] || [ -z "${ad_groups}" ]; then
        printf "Missing arguments: "
        [ -z "${app_name}" ] && printf "app_name "
        [ -z "${repo_name}" ] && printf "repo_name "
        [ -z "${repo_organization}" ] && printf "repo_organization "
        [ -z "${github_pat}" ] && printf "github_pat "
        [ -z "${ad_groups}" ] && printf "ad_groups "
        printf "\n"
        return
    fi

    # Generate shared secret
    if [ -z "${shared_secret}" ]; then
        shared_secret=$(python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())')
    fi

    template_path="${script_dir_path}/templates/radix-app-secret-template.json"

    # List deploy keys in repository
    check_key=$(curl \
        --silent \
        --request GET \
        --header "Accept: application/vnd.github.v3+json" \
        --header "Authorization: token ${github_pat}" \
        "https://api.github.com/repos/${repo_organization}/${repo_name}/keys" \
        | jq -r '.[] | select(.title=="'${deploy_key_name}'").created_at')

    if [ ${check_key} ]; then
        # Check if deploy key is older than one year.
        if [ "$(date -d "${check_key}" +%s)" -gt "$(date -d "-1 year" +%s)" ]; then
            echo "Deploy key exists and has not expired."
            return
        else
            echo "Deploy key has expired."
        fi
    else
        echo "Deploy key does not exist."
    fi

    # Generate deploy key
    printf "Generating new deploy key..."
    rm -f "${script_dir_path}/id_ed25519" "${script_dir_path}/id_ed25519.pub"

    ssh-keygen -t ed25519 -C "${owner_email}" -f "id_ed25519" -P "" -q

    private_key="$(cat "${script_dir_path}/id_ed25519")"
    public_key="$(cat "${script_dir_path}/id_ed25519.pub")"
    key_fingerprint=$(ssh-keygen -l -f "${script_dir_path}/id_ed25519.pub" | awk '{print $2}')

    rm -f "${script_dir_path}/id_ed25519" "${script_dir_path}/id_ed25519.pub"
    printf " Done.\n"

    printf "Post deploy key to GitHub..."
    curl \
        --silent \
        --request POST \
        --header "Accept: application/vnd.github.v3+json" \
        --header "Authorization: token ${github_pat}" \
        --data "{\"title\": \"${deploy_key_name}\", \"key\": \"${public_key}\", \"read_only\": true}" \
        "https://api.github.com/repos/${repo_organization}/${repo_name}/keys"
    printf " Done.\n"

    # Use jq together with a credentials json template to ensure we end up with valid json, and then put the result into a tmp file which we will upload to the keyvault.

    tmp_file_path="${script_dir_path}/${app_name}.json"
    cat "$template_path" | jq -r \
        --arg name "${app_name}" \
        --arg repository "https://github.com/${repo_organization}/${repo_name}" \
        --arg cloneURL "git@github.com:${repo_organization}/${repo_name}.git" \
        --arg configBranch "${config_branch}" \
        --arg creator "${owner_email}" \
        --arg deployKey "${private_key}" \
        --arg deployKeyFingerprint "${key_fingerprint}" \
        --arg deployKeyPublic "${public_key}" \
        --arg machineUser "${machine_user}" \
        --arg sharedSecret "${shared_secret}" \
        --arg configurationItem "${configuration_item}" \
        '.name=$name |
        .repository=$repository |
        .adGroups=['$(printf '"%s"\n' "${ad_groups//,/\",\"}")'] |
        .cloneURL=$cloneURL |
        .configBranch=$configBranch |
        .creator=$creator |
        .deployKey=$deployKey |
        .deployKeyFingerprint=$deployKeyFingerprint |
        .deployKeyPublic=$deployKeyPublic |
        .machineUser='"${machine_user}"' |
        .sharedSecret=$sharedSecret |
        .configurationItem=$configurationItem' > "$tmp_file_path"

    # 1 year from now, zulu format
    expires=$(date --utc --date "+1 year" +%FT%TZ)

    printf "Store RadixRegistration in keyvault..."
    az keyvault secret set \
        --vault-name "${AZ_RESOURCE_KEYVAULT}" \
        --name "${app_name}-radixregistration-values" \
        --file "${tmp_file_path}" \
        --expires "${expires}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --output none \
        --only-show-errors
    printf " Done.\n"

    rm -f "${tmp_file_path}"
}

function create_github_webhook_in_repository() {
    # This function will create a webhook in the repository.
    local app_name          # Input 1
    local github_pat        # Input 2
    local secret_file
    local repo_organization
    local repo_name
    local shared_secret

    app_name="${1}"
    github_pat="${2}"
    if [ -z "$app_name" ] || [ -z "${github_pat}" ]; then
      printf "Missing arguments: "
      [ -z "${app_name}" ] && printf "app_name "
      [ -z "${github_pat}" ] && printf "github_pat "
      printf "\n"
      return
    fi

    # Get secret from keyvault
    printf "Get secret from keyvault..."
    secret_file="${script_dir_path}/${app_name}-radixregistration-values.json"

    az keyvault secret download \
        --vault-name "$AZ_RESOURCE_KEYVAULT" \
        --name "${app_name}-radixregistration-values" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --file "${secret_file}" \
        --output none \
        --only-show-errors || { echo "ERROR: Could not get secret from keyvault." >&2; rm -f "${secret_file}" return; }

    printf " Done.\n"

    # Extract repo_organization and repo_name from repository url.
    repo_organization="$(cat ${secret_file} | jq -r .repository | awk -F/ '{print $4}')"
    repo_name="$(cat ${secret_file} | jq -r .repository | awk -F/ '{print $5}')"

    shared_secret=$(cat ${secret_file} | jq -r .sharedSecret)

    printf "Create GitHub webhook..."
    curl \
        --silent \
        --request POST \
        --header "Accept: application/vnd.github.v3+json" \
        --header "Authorization: token ${github_pat}" \
        --data "{\"name\":\"web\",\"active\":true,\"events\":[\"push\"],\"config\":{\"url\":\"https://webhook.${AZ_RESOURCE_DNS}/events/github\",\"secret\":\"${shared_secret}\",\"content_type\":\"json\",\"insecure_ssl\":\"0\"}}" \
        "https://api.github.com/repos/${repo_organization}/${repo_name}/hooks"
    
    rm -f "${secret_file}"
    
    printf " Done.\n"
}

function create_radix_application() {
    # This function checks if a radixRegistration exists in the cluster.
    # If not, it will download radixregistration-values from the keyvault and create a radixRegistration.
    local app_name          # Input 1
    local secret_file
    local ad_groups
    local deploy_key

    app_name="${1}"

    [ -z "$app_name" ] && { printf "Missing app_name."; return; }

    if [ -z $(kubectl get radixregistration "${app_name}" --output name 2>/dev/null) ]; then

        # Get secret from keyvault
        printf "Get secret from keyvault..."
        secret_file="${script_dir_path}/${app_name}-radixregistration-values.json"

        az keyvault secret download \
            --vault-name "$AZ_RESOURCE_KEYVAULT" \
            --name "${app_name}-radixregistration-values" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --file "${secret_file}" \
            --output none \
            --only-show-errors || { echo "ERROR: Could not get secret from keyvault." >&2; rm -f "${secret_file}"; return; }

        printf " Done.\n"

        # Generate yaml list of AD groups
        while read line; do
            ad_groups+=$(printf "\n    - ${line}")
        done <<< "$(cat ${secret_file} | jq -r .adGroups[])"

        # Convert deploy_key to yaml value
        while read line; do
            deploy_key+=$(printf "\n    ${line}")
        done <<< "$(cat ${secret_file} | jq -r .deployKey)"

        printf "Create radixregistration..."

        NAME="${app_name}" \
            AD_GROUPS="${ad_groups}" \
            CLONE_URL="$(cat ${secret_file} | jq -r .cloneURL)" \
            CONFIG_BRANCH=$(cat ${secret_file} | jq -r .configBranch) \
            DEPLOY_KEY=$(printf "|${deploy_key}") \
            DEPLOY_KEY_PUBLIC=$(cat ${secret_file} | jq -r .deployKeyPublic) \
            MACHINE_USER=$(cat ${secret_file} | jq -r .machineUser) \
            SHARED_SECRET=$(cat ${secret_file} | jq -r .sharedSecret) \
            CONFIGURATION_ITEM=$(cat ${secret_file} | jq -r .configurationItem) \
            envsubst < "${script_dir_path}/templates/radix-app-template-rr.yaml" > "${script_dir_path}/${app_name}-rr.yaml"

        kubectl apply -f "${script_dir_path}/${app_name}-rr.yaml"
        rm -f "${secret_file}" "${script_dir_path}/${app_name}-rr.yaml"
        printf " Done.\n"
    else
        echo "RadixRegistration exists."
    fi
}

function create_build_deploy_job() {
    # This downloads radixregistration-values from the keyvault and creates a radixJob.
    local app_name          # Input 1
    local clone_branch      # Input 2
    local secret_file
    local image_tag

    app_name="${1}"
    clone_branch="${2}"

    if [ -z "$app_name" ] || [ -z "$clone_branch" ]; then
        printf "Missing arguments:"
        [ -z "$app_name" ] && printf " app_name"
        [ -z "$clone_branch" ] && printf " clone_branch"
        printf ".\n"
        return
    fi

    # Get secret from keyvault
    printf "Get secret from keyvault..."
    secret_file="${script_dir_path}/${app_name}-radixregistration-values.json"

    az keyvault secret download \
        --vault-name "$AZ_RESOURCE_KEYVAULT" \
        --name "${app_name}-radixregistration-values" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --file "${secret_file}" \
        --output none \
        --only-show-errors || { echo "ERROR: Could not get secret from keyvault." >&2; rm -f "${secret_file}"; return; }

    printf " Done.\n"

    # Generate timestamp
    timestamp=$(date --utc +%Y%m%d%H%M%S)
    # Generate image tag
    image_tag=$(date +%s%N | sha256sum | base64 | head -c 5 | tr '[:upper:]' '[:lower:]')

    printf "Create radixJob..."

    NAME="${app_name}" \
        CLONE_URL=$(cat ${secret_file} | jq -r .cloneURL) \
        CLONE_BRANCH="${clone_branch}" \
        OWNER=$(cat ${secret_file} | jq -r .owner) \
        TIMESTAMP="${timestamp}" \
        IMAGE_TAG="${image_tag}" \
        CONTAINER_REGISTRY="${AZ_RESOURCE_CONTAINER_REGISTRY}.azurecr.io" \
        envsubst < "${script_dir_path}/templates/radix-app-template-rj.yaml" > "${script_dir_path}/${app_name}-rj.yaml"

    kubectl apply -f "${script_dir_path}/${app_name}-rj.yaml"
    rm -f "${secret_file}" "${script_dir_path}/${app_name}-rj.yaml"
    printf " Done.\n"
}

#######################################################################################
### Check for prerequisites binaries
###

assert_dep az helm jq sha256sum base64 python3 date awk

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [ -z "$RADIX_ZONE_ENV" ]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [ ! -f "$RADIX_ZONE_ENV" ]; then
        echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [ -z "$CLUSTER_NAME" ]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [ -z "$USER_PROMPT" ]; then
    USER_PROMPT=true
fi

if [ -z "$CREATE_BUILD_DEPLOY_JOBS" ]; then
    CREATE_BUILD_DEPLOY_JOBS=true
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Deploy radix apps will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  Radix apps                       : all of them"
echo -e "   -  Create build-deploy jobs         : ${CREATE_BUILD_DEPLOY_JOBS}"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [ $USER_PROMPT == true ]; then
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
### Deploy apps
###

# Connect kubectl so we have the correct context
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME"
[ "$(kubectl config current-context)" == "$CLUSTER_NAME" ] || { echo "ERROR: Please set your kubectl current-context to be ${CLUSTER_NAME}" >&2; exit 1; }

# Wait for operator to be deployed from flux
echo ""
echo "Waiting for radix-operator to be deployed by flux-operator so we can register radix apps"
while [[ "$(kubectl get deploy radix-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5
done
echo "Radix operator is ready, registering apps... "

# Radix Webhook
# This must be done to support deployments of application on git push.

echo ""
echo "Deploy radix-github-webhook..."

create_and_register_deploy_key_and_store_credentials \
    "radix-github-webhook" \
    "radix-github-webhook" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d" \
    "" \
    "master" \
    "true" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-github-webhook" "${GITHUB_PAT}"

create_radix_application "radix-github-webhook"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-github-webhook"

    create_build_deploy_job "radix-github-webhook" "master"

    create_build_deploy_job "radix-github-webhook" "release"
fi

# Radix API

echo ""
echo "Deploy radix-api..."

create_and_register_deploy_key_and_store_credentials \
    "radix-api" \
    "radix-api" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d" \
    "" \
    "master" \
    "true" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-api" "${GITHUB_PAT}"

create_radix_application "radix-api"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-api"

    create_build_deploy_job "radix-api" "master"

    create_build_deploy_job "radix-api" "release"
fi

# Radix Cost Allocation API

echo ""
echo "Deploy radix-cost-allocation-api..."

create_and_register_deploy_key_and_store_credentials \
    "radix-cost-allocation-api" \
    "radix-cost-allocation-api" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d" \
    "" \
    "master" \
    "true" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-cost-allocation-api" "${GITHUB_PAT}"

create_radix_application "radix-cost-allocation-api"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-cost-allocation-api"

    create_build_deploy_job "radix-cost-allocation-api" "master"

    create_build_deploy_job "radix-cost-allocation-api" "release"
fi

# Radix Canary app

echo ""
echo "Deploy radix-canary-golang..."

create_and_register_deploy_key_and_store_credentials \
    "radix-canary-golang" \
    "radix-canary-golang" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d" \
    "" \
    "master" \
    "true" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-canary-golang" "${GITHUB_PAT}"

create_radix_application "radix-canary-golang"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-canary-golang"

    create_build_deploy_job "radix-canary-golang" "master"

    create_build_deploy_job "radix-canary-golang" "release"
fi

# Radix Network Policy Canary app

echo ""
echo "Deploy radix-networkpolicy-canary..."

create_and_register_deploy_key_and_store_credentials \
    "radix-networkpolicy-canary" \
    "radix-networkpolicy-canary" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d,64b28659-4fe4-4222-8497-85dd7e43e25b,4b8ec60e-714c-4a9d-8e0a-3e4cfb3c3d31" \
    "" \
    "main" \
    "true" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-networkpolicy-canary" "${GITHUB_PAT}"

create_radix_application "radix-networkpolicy-canary"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-networkpolicy-canary"

    create_build_deploy_job "radix-networkpolicy-canary" "main"
fi

# Radix Web Console

echo ""
echo "Deploy radix-web-console..."

create_and_register_deploy_key_and_store_credentials \
    "radix-web-console" \
    "radix-web-console" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d" \
    "" \
    "master" \
    "true" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-web-console" "${GITHUB_PAT}"

create_radix_application "radix-web-console"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-web-console"

    create_build_deploy_job "radix-web-console" "master"

    create_build_deploy_job "radix-web-console" "release"
fi

# Public Web Site

echo ""
echo "Deploy radix-platform..."

create_and_register_deploy_key_and_store_credentials \
    "radix-platform" \
    "radix-public-site" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d,ec8c30af-ffb6-4928-9c5c-4abf6ae6f82e" \
    "" \
    "main" \
    "true" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-platform" "${GITHUB_PAT}"

create_radix_application "radix-platform"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-platform"

    create_build_deploy_job "radix-platform" "main"
fi

# Radix Vulnerability Scanner API

echo ""
echo "Deploy radix-vulnerability-scanner-api..."

create_and_register_deploy_key_and_store_credentials \
    "radix-vulnerability-scanner-api" \
    "radix-vulnerability-scanner-api" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d" \
    "" \
    "master" \
    "false" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-vulnerability-scanner-api" "${GITHUB_PAT}"

create_radix_application "radix-vulnerability-scanner-api"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-vulnerability-scanner-api"

    create_build_deploy_job "radix-vulnerability-scanner-api" "master"

    create_build_deploy_job "radix-vulnerability-scanner-api" "release"
fi

# Radix ServiceNow Proxy

echo ""
echo "Deploy radix-servicenow-proxy..."

create_and_register_deploy_key_and_store_credentials \
    "radix-servicenow-proxy" \
    "radix-servicenow-proxy" \
    "equinor" \
    "${GITHUB_PAT}" \
    "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d" \
    "" \
    "main" \
    "false" \
    "${DEPLOY_KEY_NAME}" \
    "2b0781a7db131784551ea1ea4b9619c9"

create_github_webhook_in_repository "radix-servicenow-proxy" "${GITHUB_PAT}"

create_radix_application "radix-servicenow-proxy"

if [ "${CREATE_BUILD_DEPLOY_JOBS}" == true ]; then
    # Wait a few seconds until radix-operator can process the RadixRegistration
    wait_for_app_namespace "radix-servicenow-proxy"

    create_build_deploy_job "radix-servicenow-proxy" "main"

    create_build_deploy_job "radix-servicenow-proxy" "release"
fi

#######################################################################################
### Applications have been deployed. Start configuration.
###

# Update replyUrl for web-console
AUTH_PROXY_COMPONENT="auth"
AUTH_PROXY_REPLY_PATH="/oauth2/callback"
WEB_REDIRECT_URI="/applications"
WEB_COMPONENT="web"
RADIX_WEB_CONSOLE_ENV="prod"
if [ "${CLUSTER_TYPE}"  == "development" ]; then
    # Development cluster uses QA web-console
    RADIX_WEB_CONSOLE_ENV="qa"
fi
WEB_CONSOLE_NAMESPACE="radix-web-console-${RADIX_WEB_CONSOLE_ENV}"

echo ""
echo "Waiting for web-console ingress to be ready so we can add replyUrl to web console aad app..."
while [ "$(kubectl get ingress "${AUTH_PROXY_COMPONENT}" --namespace "${WEB_CONSOLE_NAMESPACE}" 2>&1)" == *"Error"* ]; do
    printf "."
    sleep 5
done

echo "Ingress is ready, adding replyUrl for radix web-console..."

(AAD_APP_NAME="Omnia Radix Web Console - ${CLUSTER_TYPE^} Clusters" K8S_NAMESPACE="${WEB_CONSOLE_NAMESPACE}" K8S_INGRESS_NAME="${AUTH_PROXY_COMPONENT}" REPLY_PATH="${AUTH_PROXY_REPLY_PATH}" WEB_REDIRECT_URI="${WEB_REDIRECT_URI}" "${script_dir_path}/../../add_reply_url_for_cluster.sh")
wait # wait for subshell to finish


echo ""
echo "For the web console to work we need to apply the secrets for the auth proxy"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" AUTH_PROXY_COMPONENT="${AUTH_PROXY_COMPONENT}" WEB_COMPONENT="$WEB_COMPONENT" WEB_CONSOLE_NAMESPACE="${WEB_CONSOLE_NAMESPACE}" AUTH_PROXY_REPLY_PATH="${AUTH_PROXY_REPLY_PATH}" "${script_dir_path}/../../update_auth_proxy_secret_for_console.sh")
wait # wait for subshell to finish

echo ""
echo "For the web console to work we need to apply the secrets for the Redis Cache"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" AUTH_PROXY_COMPONENT="${AUTH_PROXY_COMPONENT}" CLUSTER_NAME="${CLUSTER_NAME}" RADIX_WEB_CONSOLE_ENV="qa" "${script_dir_path}/../../redis/update_redis_cache_for_console.sh")
wait # wait for subshell to finish
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" AUTH_PROXY_COMPONENT="${AUTH_PROXY_COMPONENT}" CLUSTER_NAME="${CLUSTER_NAME}" RADIX_WEB_CONSOLE_ENV="prod" "${script_dir_path}/../../redis/update_redis_cache_for_console.sh")
wait # wait for subshell to finish

echo ""
echo "For the networkpolicy-canary to work, we need to apply the HTTP password"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" CLUSTER_NAME="${CLUSTER_NAME}" "${script_dir_path}/../../cicd-canary/update_secret_for_networkpolicy_canary.sh")
wait # wait for subshell to finish

echo ""
echo "Waiting for radix-api ingress to be ready so that the web console can work properly..."
while [ "$(kubectl get ing server -n radix-api-prod 2>&1)" == *"Error"* ]; do
    printf "."
    sleep 5
done

echo ""
echo "Radix API-s ingress is ready, restarting web console... "
kubectl delete pods $(kubectl get pods -n "${WEB_CONSOLE_NAMESPACE}" -o custom-columns=':metadata.name' --no-headers | grep web) -n "${WEB_CONSOLE_NAMESPACE}"

### Set Radix Web Console env vars
echo ""
echo "For the web console to work we need to apply env vars for list of all IPs assigned to the cluster type"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" WEB_COMPONENT="${WEB_COMPONENT}" CLUSTER_NAME="${CLUSTER_NAME}" RADIX_WEB_CONSOLE_ENV="qa" "${script_dir_path}/../../update_ips_env_vars_for_console.sh")
wait # wait for subshell to finish
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" WEB_COMPONENT="${WEB_COMPONENT}" CLUSTER_NAME="${CLUSTER_NAME}" RADIX_WEB_CONSOLE_ENV="prod" "${script_dir_path}/../../update_ips_env_vars_for_console.sh")
wait # wait for subshell to finish

### Set Radix API env vars
echo ""
echo "Update Radix API env vars"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" CLUSTER_NAME="${CLUSTER_NAME}" "${script_dir_path}/../../update_env_vars_for_radix_api.sh")
wait

### Set Radix Cost Allocation API secrets
echo ""
echo "For the cost allocation api to work we need to apply secrets"
wait_for_app_namespace_component_secret "radix-cost-allocation-api-qa" "server"
wait_for_app_namespace_component_secret "radix-cost-allocation-api-prod" "server"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" CLUSTER_NAME="${CLUSTER_NAME}" "${script_dir_path}/../../update_secret_for_cost_allocation_api.sh")
wait # wait for subshell to finish

### Set Radix Vulnerability Scanner API secrets
echo ""
echo "For the vulnerability scanner api to work we need to apply secrets"
wait_for_app_namespace_component_secret "radix-vulnerability-scanner-api-qa" "server"
wait_for_app_namespace_component_secret "radix-vulnerability-scanner-api-prod" "server"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" CLUSTER_NAME="${CLUSTER_NAME}" "${script_dir_path}/../../update_secret_for_vulnerability_scanner_api.sh")
wait # wait for subshell to finish

### Set Radix ServiceNow Proxy secrets
echo ""
echo "For the Radix ServiceNow Proxy to work we need to apply secrets"
wait_for_app_namespace_component_secret "radix-servicenow-proxy-qa" "api"
wait_for_app_namespace_component_secret "radix-servicenow-proxy-prod" "api"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" CLUSTER_NAME="${CLUSTER_NAME}" "${script_dir_path}/../../update_secret_for_radix_servicenow_proxy.sh")
wait # wait for subshell to finish

### All done
echo ""
echo "Roses are red, violets are blue"
echo "the deployment of radix apps has come to an end"
echo "but maybe not so"
echo "for all the remaining tasks assigned to you"
echo ""

