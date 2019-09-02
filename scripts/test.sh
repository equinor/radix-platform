#!/bin/bash

NUM_NODES_IN_SOURCE_CLUSTER="$(kubectl get nodes --no-headers | wc -l)"
echo "$NUM_NODES_IN_SOURCE_CLUSTER"