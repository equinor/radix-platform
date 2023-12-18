#!/usr/bin/env bash

repos=$(az acr repository list --name radixdev --output json)

while read repo; do
  printf "Importing repo %s\n" "${repo}"
  tags=$(az acr repository show-tags -n radixdev --repository "${repo}" --output json --orderby time_desc)

  while read tag; do
    printf "  tag %s\n" "${tag}"
    az acr import -n radixdevdr --source "radixdev.azurecr.io/${repo}:${tag}"  --username import --password "<Source repo token password>" --no-wait
  done <<<"$(echo ${tags} | jq -r '.[0:10] | .[]')"

done <<<"$(echo ${repos} | jq -r '.[]' | grep radix-)"
