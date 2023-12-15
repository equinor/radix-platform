#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Library for often used ACR functions.

#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nERROR: jq not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### FUNCTIONS
###

function create_acr() {
    # Create ACR
    if [[ -z $(az acr show --name "${AZ_RESOURCE_CONTAINER_REGISTRY}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "name" -otsv 2>/dev/null) ]]; then
        printf "Azure Container Registry ${AZ_RESOURCE_CONTAINER_REGISTRY} does not exist.\n"
        if [[ $USER_PROMPT == true ]]; then
            while true; do
                read -p "Create Azure Container Registry: ${AZ_RESOURCE_CONTAINER_REGISTRY}? (Y/n) " yn
                case $yn in
                [Yy]*) break ;;
                [Nn]*)
                    echo ""
                    echo "Return."
                    return
                    ;;
                *) echo "Please answer yes or no." ;;
                esac
            done
        fi

        printf "Creating Azure Container Registry: ${AZ_RESOURCE_CONTAINER_REGISTRY}...\n"
        az acr create \
            --name "${AZ_RESOURCE_CONTAINER_REGISTRY}" \
            --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
            --sku "Premium" \
            --location "${AZ_RADIX_ZONE_LOCATION}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --default-action "Deny" \
            --public-network-enabled "true" \
            --output none
        printf "...Done\n"
    else
        printf "ACR ${AZ_RESOURCE_CONTAINER_REGISTRY} already exists.\n"
    fi
}


function set_permissions_on_acr() {
    local scope
    scope="$(az acr show --name ${AZ_RESOURCE_CONTAINER_REGISTRY} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

    # Available roles
    # https://github.com/Azure/acr/blob/master/docs/roles-and-permissions.md
    # Note that to be able to use "az acr build" you have to have the role "Contributor".

    local id
    printf "Working on container registry \"${AZ_RESOURCE_CONTAINER_REGISTRY}\": "

    printf "Setting permissions for \"${AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER}\"..." # radix-cr-reader-dev
    id="$(az ad sp list --display-name ${AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER} --query [].appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}" --output none
    # Configure new roles
    az role assignment create --assignee "${id}" --role AcrPull --scope "${scope}" --output none

    printf "Setting permissions for \"${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD}\"..." # radix-cr-cicd-dev
    id="$(az ad sp list --display-name ${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD} --query [].appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}" --output none
    # Configure new roles
    az role assignment create --assignee "${id}" --role Contributor --scope "${scope}" --output none

    printf "...Done\n"
}

function create_acr_tasks() {
    ./acr_task.sh
}


## ACR TASK
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
    if [[ ${tier} == "${AGENT_POOL_TIER}" ]]; then
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

    if agent_pool_exists "${AGENT_POOL_NAME}" "${ACR_NAME}"; then
        if agent_pool_has_correct_tier "${AGENT_POOL_NAME}" "${ACR_NAME}" "${AGENT_POOL_TIER}"; then
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

function create_acr_task() {
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    local AGENT_POOL_NAME="$3"
    local TASK_YAML="/tmp/task.yaml"
    test -f "$TASK_YAML" && rm "$TASK_YAML"
    cat <<EOF >>${TASK_YAML}
version: v1.1.0
stepTimeout: 3600
steps:
  - build: >-
      --tag {{.Values.IMAGE}}
      --tag {{.Values.CLUSTERTYPE_IMAGE}}
      --tag {{.Values.CLUSTERNAME_IMAGE}}
      --file {{.Values.DOCKER_FILE_NAME}}
      .
      {{.Values.BUILD_ARGS}}
  - push:
      - {{.Values.IMAGE}}
      - {{.Values.CLUSTERTYPE_IMAGE}}
      - {{.Values.CLUSTERNAME_IMAGE}}
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

function create_acr_task_build_only() {
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    local AGENT_POOL_NAME="$3"
    local TASK_YAML="/tmp/task.yaml"
    test -f "$TASK_YAML" && rm "$TASK_YAML"
    cat <<EOF >>${TASK_YAML}
version: v1.1.0
stepTimeout: 3600
steps:
  - build: >-
      --tag {{.Values.IMAGE}}
      --tag {{.Values.CLUSTERTYPE_IMAGE}}
      --tag {{.Values.CLUSTERNAME_IMAGE}}
      --file {{.Values.DOCKER_FILE_NAME}}
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

function create_acr_task_with_cache() {
    local TASK_NAME="$1"
    local ACR_NAME="$2"
    local AGENT_POOL_NAME="$3"
    local TASK_YAML="/tmp/task.yaml"
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
      {{.Values.BUILD_ARGS}} {{.Values.SECRET_ARGS}}
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
    local TASK_YAML="/tmp/task_internal.yaml"
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