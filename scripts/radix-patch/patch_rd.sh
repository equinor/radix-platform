#!/bin/bash

# PURPOSE
#
# The purpose of the shell script is to patch RadixDeployments to cater for changes in the Radix operator
# so that no customer application is broken

DESTINATION_CLUSTER="$(kubectl config current-context)"

echo ""
echo "WARNIG!"
echo "This script is a tool for patching RadixDeployments to cater"
echo "for changes in the Radix operator so that no customer application"
echo "is broken."
echo ""
echo "Current cluster is: $DESTINATION_CLUSTER"
echo ""

read -p "Are you sure you want to continue? (Y/n) " really_sure
if [[ $really_sure =~ (N|n) ]]; then
  echo "Chicken!1"
  exit 1
fi

#######################################################################################

while read -r line; do
    if [[ "$line" ]]; then
        stringarray=($line)
        name=${stringarray[0]}
        namespace=${stringarray[1]}
        replicas=${stringarray[2]}

        index=0

        for replica in $(echo $replicas | sed "s/,/ /g")
        do
            if [[ ""${replica}"" == "0" ]]; then
                $(kubectl patch rd $name -p "[{'op': 'replace', 'path': "/spec/components/$index/replicas",'value': 1}]" --type json -n $namespace 2>&1 >/dev/null)
                echo "Patched $name in $namespace"
            fi

            index=$((index+1))
        done      
    fi
done <<< "$(kubectl get rd --all-namespaces -o custom-columns=':metadata.name, :metadata.namespace, :spec.components[*].replicas, :status.condition' | grep 'Active')"