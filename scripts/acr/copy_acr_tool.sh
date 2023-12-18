#!/usr/bin/env bash

srcRegistry="radixdev"
dstRegistry="radixdevdr"
repos=$(az acr repository list --name "${srcRegistry}"  --output json)

while read repo; do
  printf "Importing repo %s\n" "${repo}"
  tags=$(az acr repository show-tags --name "${srcRegistry}" --repository "${repo}" --output json --orderby time_desc)

  while read tag; do
    printf "  tag %s\n" "${tag}"
    az acr import -n "${dstRegistry}" --source "${srcRegistry}.azurecr.io/${repo}:${tag}"  --username <source-username> --password "<source-password>" --no-wait
  done <<<"$(echo ${tags} | jq -r '.[0:10] | .[]')"

done <<<"$(echo ${repos} | jq -r '.[]')"
