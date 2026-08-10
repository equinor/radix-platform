#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Patch all PDB's in cluster to allow teardown

#######################################################################################

clustername="$(kubectl config current-context)"

for row in $(kubectl --context "$clustername" get pdb -A -o json | jq -c '.items[] | select(.spec.minAvailable == 1) | {namespace: .metadata.namespace, name: .metadata.name, minAvailable: .spec.minAvailable}'); do
  namespace=$(echo "$row" | jq -r '.namespace')
  name=$(echo "$row" | jq -r '.name')
  minAvailable=$(echo "$row" | jq -r '.minAvailable')
  kubectl --context "$clustername" patch pdb -n ${namespace} ${name} -p '{"spec":{"minAvailable":0}}'
done