#!/bin/bash

# PURPOSE
#
# The purpose of the shell script is to patch RadixDeployments to cater for changes in the Radix operator
# so that no customer application is broken

DESTINATION_CLUSTER="$(kubectl config current-context)"

echo ""
echo "WARNING!"
echo "This script is a tool for patching RadixDeployments to cater"
echo "for changes in the Radix operator so that no customer application"
echo "is broken."
echo ""
echo "Current cluster is: $DESTINATION_CLUSTER"
echo ""

read -p "Are you sure you want to continue? (Y/n) " really_sure
if [[ $really_sure =~ (N|n) ]]; then
  echo "Chicken!"
  exit 1
fi

#######################################################################################

while read -r line; do
    if [[ "$line" ]]; then
        stringarray=($line)
        name=${stringarray[0]}
        namespace=${stringarray[1]}

        $(kubectl delete rd $name -n $namespace 2>&1 >/dev/null)
        echo "Deleted $name in $namespace"        
    fi
done <<< "$(kubectl get rd --all-namespaces -o custom-columns=':metadata.name, :metadata.namespace, :status.condition' | grep 'Inactive')"