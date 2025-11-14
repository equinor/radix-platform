#!/usr/bin/env bash
#######################################################################################
### PURPOSE
###
# Clean up old cache registry images
#######################################################################################
### INPUTS
###
# Required:
# - REGISTRY=radixdevapp|radixplaygroundapp|radixprodapp|radixc2app ./clean-cache-registry.sh
#######################################################################################
### Read inputs and configs
###
if [[ -z "$REGISTRY" ]]; then
    echo "ERROR: Please provide REGISTRY" >&2
    exit 1
fi


set -e
DAYS_AGO=$(date -d '7 days ago' +%s)
az acr login --name $REGISTRY
for repo in $(az acr repository list --name $REGISTRY --output tsv | grep '/cache'); do
  echo "Processing repository: $repo"
  for tag in $(az acr repository show-tags --name $REGISTRY --repository $repo --output tsv); do
    created=$(az acr manifest list-metadata \
    --registry $REGISTRY \
    --name $repo \
    --query "[?tags && contains(tags,'$tag')].createdTime | [0]" \
    --only-show-errors \
    --output tsv)
  
    if [[ -n "$created" ]]; then
      # echo "Tag: $tag, Created: $created"
      created_ts=$(date -d "$created" +%s)
      if [[ $created_ts -lt $DAYS_AGO ]]; then
        echo "Deleting $repo:$tag (created $created)..."
        az acr repository delete \
          --name $REGISTRY \
          --image $repo:$tag \
          --yes
      fi
    fi
  done

  # Delete untagged manifests
  for digest in $(az acr manifest list-metadata \
    --registry $REGISTRY \
    --name $repo \
    --query "[?tags==null && lastUpdateTime < '$(date -u -d '7 days ago' --iso-8601=seconds)' && !deleteEnabled].digest" \
    --only-show-errors \
    --output tsv); do
    echo "Deleting untagged manifest $digest..."
    az acr repository delete \
      --name $REGISTRY \
      --image $repo@$digest \
      --yes
  done

done