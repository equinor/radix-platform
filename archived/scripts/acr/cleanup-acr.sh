#!/bin/bash

# sh ./cleanup-acr.sh radixdev

SOURCE_ACR=$1

REPOS=$(az acr repository list --name "${SOURCE_ACR}" --output tsv )

for REPO in $REPOS; do 
    tags=$(az acr repository show-tags --name "${SOURCE_ACR}" --repository "${REPO}" --orderby time_desc --output tsv)
    if [[ -z "${tags}" ]]; then
        echo "Repo $REPO will be deleted"
            az acr import --name "${SOURCE_ACR}" --source "${SOURCE_ACR}.azurecr.io/alpine-rootless-deleteme:latest" --image "${REPO}:latest"
            az acr repository delete -y --name "${SOURCE_ACR}" --repository "${REPO}"
    else
    count=0
    for tag in $tags; do
        count=$((count+1))
    done
        echo "There are $count tags in $REPO "
    fi



 done

