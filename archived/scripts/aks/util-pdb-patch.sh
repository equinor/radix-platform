#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Patch all PDB's in cluster to allow teardown

#######################################################################################

if [[ -z "$CLUSTER_NAME" ]]; then
  echo "ERROR: Please provide CLUSTER_NAME" >&2
  exit 1
fi

kubectl --context "$CLUSTER_NAME" cluster-info >/dev/null 2>&1 || {
  echo "ERROR: Could not access cluster context $CLUSTER_NAME. Quitting..." >&2
  exit 1
}

for row in $(kubectl --context "$CLUSTER_NAME" get pdb -A -o json | jq -c '.items[] | select(.spec.minAvailable == 1) | {namespace: .metadata.namespace, name: .metadata.name, minAvailable: .spec.minAvailable}'); do
  namespace=$(echo "$row" | jq -r '.namespace')
  name=$(echo "$row" | jq -r '.name')
  minAvailable=$(echo "$row" | jq -r '.minAvailable')
  kubectl --context "$CLUSTER_NAME" patch pdb -n ${namespace} ${name} -p '{"spec":{"minAvailable":0}}'
done