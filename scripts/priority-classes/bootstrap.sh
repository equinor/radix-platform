#!/bin/bash

#######################################################################################
### PURPOSE
###

# Bootstrap priority classes in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of priority classes creating... "

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME" >&2
    exit 1
fi

echo "Create priority classes"
kubectl apply -f radixComponentPriorityClass.yaml
echo "Done."