#!/bin/bash

set -e

export SOURCE_ACR="radixc2prod"
export TARGET_ACR="radixc3"
export SOURCE_SUBSCRIPTION_ID="ded7ca41-37c8-4085-862f-b11d21ab341a"
export TARGET_SUBSCRIPTION_ID="ded7ca41-37c8-4085-862f-b11d21ab341a"
export SOURCE_RESOURCE_GROUP="common-c2"

az account set --subscription "${SOURCE_SUBSCRIPTION_ID}"
repos=$(az acr repository list --name "${SOURCE_ACR}" --output tsv | grep radix-)

import_images() {
    local repo=$1
    echo "Processing repository: ${repo}"
    tags=$(az acr repository show-tags --name "${SOURCE_ACR}" --subscription "${SOURCE_SUBSCRIPTION_ID}" --repository "${repo}" --orderby time_desc --output tsv | head -n 15)
    existing_tags=$(az acr repository show-tags --name "${TARGET_ACR}" --subscription "${TARGET_SUBSCRIPTION_ID}" --repository "${repo}" --orderby time_desc --output tsv)

    for tag in $tags; do
        if echo "${existing_tags}" | grep --silent "${tag}"; then
            echo "Tag: ${tag} already exists in repository ${repo}. Skipping import."
            continue
        fi

        echo "Processing tag: ${tag} in repository ${repo}..."
        az acr import \
            --name "${TARGET_ACR}" \
            --source "${repo}:${tag}" \
            --subscription $TARGET_SUBSCRIPTION_ID \
            --registry "/subscriptions/${SOURCE_SUBSCRIPTION_ID}/resourceGroups/${SOURCE_RESOURCE_GROUP}/providers/Microsoft.ContainerRegistry/registries/${SOURCE_ACR}"
    done
}

export -f import_images

echo $repos | xargs -d ' ' -I'{}' -n1 -P10 bash -c 'import_images {}'
