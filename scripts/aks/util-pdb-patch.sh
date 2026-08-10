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

clustername="$CLUSTER_NAME"

kubectl --context "$clustername" cluster-info >/dev/null 2>&1 || {
  echo "ERROR: Could not access cluster context $clustername. Quitting..." >&2
  exit 1
}

for row in $(kubectl --context "$clustername" get pdb -A -o json | jq -c '.items[] | select(.spec.minAvailable == 1) | {namespace: .metadata.namespace, name: .metadata.name, minAvailable: .spec.minAvailable}'); do
  namespace=$(echo "$row" | jq -r '.namespace')
  name=$(echo "$row" | jq -r '.name')
  minAvailable=$(echo "$row" | jq -r '.minAvailable')
  kubectl --context "$clustername" patch pdb -n ${namespace} ${name} -p '{"spec":{"minAvailable":0}}'
done