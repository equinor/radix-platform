#!/usr/bin/env bash

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

while true; do
    read -p "Are you sure you want to continue? (Y/n) " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo ""; echo "Chicken!"; exit 0;;
        * ) echo "Please answer yes or no.";;
    esac
done

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