#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create Azure Container Registry (ACR) Task
# This script will: 
# - create an ACR Task with a system-assigned identity
# - grant the Task system-assigned identity access to push to ACR
# - add credentials using the system-assigned identity to the task

#######################################################################################
### DOCS
###

# https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tasks-authentication-managed-identity
# https://docs.microsoft.com/en-us/azure/container-registry/allow-access-trusted-services#example-acr-tasks

#######################################################################################
### PRECONDITIONS
###

# - ACR Exists

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix_zone_dev.env ./acr_task.sh

#######################################################################################
### START
###

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
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

if [[ -z "$AZ_RESOURCE_CONTAINER_REGISTRY" ]]; then
    echo "ERROR: AZ_RESOURCE_CONTAINER_REGISTRY not defined. Exiting..." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_ACR_TASK_NAME" ]]; then
    echo "ERROR: AZ_RESOURCE_ACR_TASK_NAME not defined. Exiting..." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_ACR_INTERNAL_TASK_NAME" ]]; then
    echo "ERROR: AZ_RESOURCE_ACR_INTERNAL_TASK_NAME not defined. Exiting..." >&2
    exit 1
fi

# Optional inputs

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
echo -e "Create ACR Task with the following configuration:"
echo -e ""
echo -e "   > WHAT:"
echo -e "   --------------------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_CONTAINER_REGISTRY       : $AZ_RESOURCE_CONTAINER_REGISTRY"
echo -e "   -  AZ_RESOURCE_ACR_TASK_NAME            : $AZ_RESOURCE_ACR_TASK_NAME";
echo -e "   -  AZ_RESOURCE_ACR_INTERNAL_TASK_NAME   : $AZ_RESOURCE_ACR_INTERNAL_TASK_NAME";
echo -e "   -  AZ_RESOURCE_ACR_AGENT_POOL_TASK_NAME : $AZ_RESOURCE_ACR_AGENT_POOL_TASK_NAME";
echo -e "   -  AZ_RESOURCE_ACR_AGENT_POOL_NAME      : $AZ_RESOURCE_ACR_AGENT_POOL_NAME";
echo -e "   -  AZ_RESOURCE_ACR_AGENT_POOL_TIER      : $AZ_RESOURCE_ACR_AGENT_POOL_TIER";
echo -e "   -  AZ_RESOURCE_ACR_AGENT_POOL_COUNT     : $AZ_RESOURCE_ACR_AGENT_POOL_COUNT";
echo -e ""
echo -e "   > WHO:"
echo -e "   --------------------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                      : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                              : $(az account show --query user.name -o tsv)"
echo -e ""
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

function agent_pool_exists() {
    local AGENT_POOL_NAME="$1"
    local ACR_NAME="$2"
    az acr agentpool show --registry ${ACR_NAME} --name "${AGENT_POOL_NAME}"
    return
}

function agent_pool_has_correct_tier() {
    local AGENT_POOL_NAME="$1"
    local ACR_NAME="$2"
    tier=$(az acr agentpool show --registry ${ACR_NAME} --name "${AGENT_POOL_NAME}" | jq .tier --raw-output)
    if [[ ${tier} == "${AGENT_POOL_TIER}" ]]
    then
      return 0
    else
      printf "Current agent pool has tier ${tier}, but desired new tier is ${AGENT_POOL_TIER}. Deleting and recreating agent pool..."
      return 1
    fi
}

function create_agent_pool() {
    local AGENT_POOL_NAME="$1"
    local ACR_NAME="$2"
    local AGENT_POOL_TIER="$3"
    local AGENT_POOL_COUNT="$4"

    if agent_pool_exists "${AGENT_POOL_NAME}" "${ACR_NAME}"
    then
      if agent_pool_has_correct_tier "${AGENT_POOL_NAME}" "${ACR_NAME}" "${AGENT_POOL_TIER}"
      then
        printf "Updating ACR Task agent pool: ${AGENT_POOL_NAME}, tier ${AGENT_POOL_TIER}, count ${AGENT_POOL_COUNT}, in ACR: ${ACR_NAME}..."
        az acr agentpool update \
        --name $AGENT_POOL_NAME \
        --registry $ACR_NAME \
        --count $AGENT_POOL_COUNT
        return
      else
        printf "Deleting ACR Task agent pool: ${AGENT_POOL_NAME} in ACR: ${ACR_NAME}..."
      fi
    fi

    printf "Creating ACR Task agent pool: ${AGENT_POOL_NAME}, tier ${AGENT_POOL_TIER}, count ${AGENT_POOL_COUNT}, in ACR: ${ACR_NAME}..."
    az acr agentpool create \
        --name $AGENT_POOL_NAME \
        --registry $ACR_NAME \
        --tier $AGENT_POOL_TIER
}

function create_agentpool_acr_task() {
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    local AGENT_POOL_NAME="$3"
    local TASK_YAML="task.yaml"
    test -f "$TASK_YAML" && rm "$TASK_YAML"
    cat <<EOF >>${TASK_YAML}
version: v1.1.0
stepTimeout: 3600
steps:
  - cmd: buildx create --use # start buildkit
  - cmd: >-
      buildx build {{.Values.PUSH}} {{.Values.CACHE}}
      --tag {{.Values.IMAGE}}
      --tag {{.Values.CLUSTERTYPE_IMAGE}}
      --tag {{.Values.CLUSTERNAME_IMAGE}}
      --file {{.Values.DOCKER_FILE_NAME}}
      --cache-from=type=registry,ref={{.Values.DOCKER_REGISTRY}}.azurecr.io/{{.Values.REPOSITORY_NAME}}:radix-cache-{{.Values.BRANCH}} {{.Values.CACHE_TO_OPTIONS}}
      .
      {{.Values.BUILD_ARGS}}
EOF
    printf "Create ACR Task with agent pool: ${TASK_NAME} in ACR: ${ACR_NAME}..."
    az acr task create \
        --registry ${ACR_NAME} \
        --agent-pool "${AGENT_POOL_NAME}" \
        --name ${TASK_NAME} \
        --context /dev/null \
        --file ${TASK_YAML} \
        --assign-identity [system] \
        --auth-mode None \
        --output none

    rm "$TASK_YAML"
    printf " Done.\n"
}

function create_internal_acr_task() {
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    local TASK_YAML="task_internal.yaml"
    test -f "$TASK_YAML" && rm "$TASK_YAML"
    cat <<EOF >>${TASK_YAML}
version: v1.1.0
stepTimeout: 3600
steps:
  - cmd: buildx create --use # start buildkit
  - cmd: >-
      buildx build {{.Values.PUSH}} {{.Values.CACHE}} 
      {{.Values.TAGS}} 
      --file {{.Values.DOCKER_FILE_NAME}} 
      --cache-from=type=registry,ref={{.Values.DOCKER_REGISTRY}}.azurecr.io/{{.Values.REPOSITORY_NAME}}:radix-cache-{{.Values.BRANCH}} {{.Values.CACHE_TO_OPTIONS}} 
      . 
      {{.Values.BUILD_ARGS}} 
EOF
    printf "Create ACR Task for internal use: ${TASK_NAME} in ACR: ${ACR_NAME}..."
    az acr task create \
        --registry ${ACR_NAME} \
        --name ${TASK_NAME} \
        --context /dev/null \
        --file ${TASK_YAML} \
        --assign-identity [system] \
        --auth-mode None \
        --output none

    rm "$TASK_YAML"
    printf " Done.\n"
}

function create_acr_task() {
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    local TASK_YAML="task.yaml"
    test -f "$TASK_YAML" && rm "$TASK_YAML"
    cat <<EOF >>${TASK_YAML}
version: v1.1.0
stepTimeout: 3600
steps:
  - cmd: buildx create --use # start buildkit
  - cmd: >-
      buildx build {{.Values.PUSH}} {{.Values.CACHE}}
      --tag {{.Values.IMAGE}}
      --tag {{.Values.CLUSTERTYPE_IMAGE}}
      --tag {{.Values.CLUSTERNAME_IMAGE}}
      --file {{.Values.DOCKER_FILE_NAME}}
      --cache-from=type=registry,ref={{.Values.DOCKER_REGISTRY}}.azurecr.io/{{.Values.REPOSITORY_NAME}}:radix-cache-{{.Values.BRANCH}} {{.Values.CACHE_TO_OPTIONS}}
      .
      {{.Values.BUILD_ARGS}}
EOF
    printf "Create ACR Task: ${TASK_NAME} in ACR: ${ACR_NAME}..."
    az acr task create \
        --registry ${ACR_NAME} \
        --name ${TASK_NAME} \
        --context /dev/null \
        --file ${TASK_YAML} \
        --assign-identity [system] \
        --auth-mode None \
        --output none

    rm "$TASK_YAML"
    printf " Done.\n"
}

function create_role_assignment(){
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    printf "Get ID of ACR: ${ACR_NAME}..."
    REGISTRY_ID=$(az acr show --name ${ACR_NAME} --query id --output tsv)
    printf "Done.\n"

    printf "Get ID of task: ${TASK_NAME}..."
    TASK_IDENTITY=$(az acr task show --name ${TASK_NAME} --registry ${ACR_NAME} --query identity.principalId --output tsv)
    printf " Done.\n"

    printf "Create role assignment..."
    az role assignment create \
        --assignee $TASK_IDENTITY \
        --scope $REGISTRY_ID \
        --role "AcrPush" \
        --output none \
        2>/dev/null
    printf " Done.\n"
}

function add_task_credential() {
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    printf "Add credentials for system-assigned identity to task: ${TASK_NAME}..."
    if [[ 
        $(az acr task credential list --registry ${ACR_NAME} --name ${TASK_NAME} | jq '.["'${ACR_NAME}'.azurecr.io"].identity') == null ||
        -z $(az acr task credential list --registry ${ACR_NAME} --name ${TASK_NAME} | jq '.["'${ACR_NAME}'.azurecr.io"].identity')
    ]]; then
        # Add credentials for user-assigned identity to the task
        az acr task credential add \
            --name ${TASK_NAME} \
            --registry ${ACR_NAME} \
            --login-server ${ACR_NAME}.azurecr.io \
            --use-identity [system] \
            &>/dev/null
        printf " Done.\n"
    else
        printf " Credential exists.\n"
    fi
}

function run_task() {
    # This function is for testing the ACR task.
    # It can use a remote context or a local context.
    echo "run task..."
    #CONTEXT="https://github.com/equinor/radix-app.git#main:frontend" # https://github.com/organization/repo.git#branch:directory - Can be path to local git repo directory
    CONTEXT="/local/path/to/equinor/radix-app/frontend" # Path to local context

    REPOSITORY_NAME="test-acr-task-notused-deleteme"
    DOCKER_FILE_NAME="Dockerfile"
    IMAGE="radixdev.azurecr.io/test-acr-task-notused-deleteme:abcdef"
    CLUSTERTYPE_IMAGE="radixdev.azurecr.io/test-acr-task-notused-deleteme:development-abcdef"
    CLUSTERNAME_IMAGE="radixdev.azurecr.io/test-acr-task-notused-deleteme:weekly-notexisting-abcdef"
    BRANCH="main"

    # Build arguments
    TARGET_ENVIRONMENTS="dev qa"
    RADIX_GIT_TAGS="v1.12 v1.13"
    BUILD_ARGS="--build-arg TARGET_ENVIRONMENTS=\\\"${TARGET_ENVIRONMENTS}\\\" "
    BUILD_ARGS+="--build-arg BRANCH=\"${BRANCH}\" "
    BUILD_ARGS+="--build-arg RADIX_GIT_TAGS=\\\"${RADIX_GIT_TAGS}\\\" "

    CACHE_DISABLED=true
    if [[ ${CACHE_DISABLED} == true ]]; then
        CACHE="--no-cache"
    else
        CACHE_TO_OPTIONS="--cache-to=type=registry,ref=${AZ_RESOURCE_CONTAINER_REGISTRY}/${REPOSITORY_NAME}:radix-cache-${BRANCH},mode=max"
    fi

    NO_PUSH=true
    if [[ ${NO_PUSH} != true ]]; then
        PUSH="--push"
    fi

    az acr task run \
        --name "${AZ_RESOURCE_ACR_TASK_NAME}" \
        --registry "${AZ_RESOURCE_CONTAINER_REGISTRY}" \
        --context "${CONTEXT}" \
        --file "${CONTEXT}${DOCKER_FILE_NAME}" \
        --set REPOSITORY_NAME="${REPOSITORY_NAME}" \
        --set IMAGE=${IMAGE} \
        --set CLUSTERTYPE_IMAGE=${CLUSTERTYPE_IMAGE} \
        --set CLUSTERNAME_IMAGE=${CLUSTERNAME_IMAGE} \
        --set DOCKER_FILE_NAME="${DOCKER_FILE_NAME}" \
        --set BRANCH="${BRANCH}" \
        --set BUILD_ARGS="${BUILD_ARGS}" \
        --set PUSH="${PUSH}" \
        --set CACHE="${CACHE}" \
        --set CACHE_TO_OPTIONS="${CACHE_TO_OPTIONS}"

    echo $? # Exit code of last executed command.

    echo "Done."
}

create_acr_task "${AZ_RESOURCE_ACR_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
create_role_assignment "${AZ_RESOURCE_ACR_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
add_task_credential "${AZ_RESOURCE_ACR_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"

create_internal_acr_task "${AZ_RESOURCE_ACR_INTERNAL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
create_role_assignment "${AZ_RESOURCE_ACR_INTERNAL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
add_task_credential "${AZ_RESOURCE_ACR_INTERNAL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"

create_agent_pool "${AZ_RESOURCE_ACR_AGENT_POOL_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}" "${AZ_RESOURCE_ACR_AGENT_POOL_TIER}" "${AZ_RESOURCE_ACR_AGENT_POOL_COUNT}"
create_agentpool_acr_task "${AZ_RESOURCE_ACR_AGENT_POOL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}" "${AZ_RESOURCE_ACR_AGENT_POOL_NAME}"
create_role_assignment "${AZ_RESOURCE_ACR_AGENT_POOL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
add_task_credential "${AZ_RESOURCE_ACR_AGENT_POOL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"

#run_task # Uncomment this line to test the task

echo ""
echo "Done creating ACR Tasks."
