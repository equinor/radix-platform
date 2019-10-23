#!/bin/bash

# Set alias script vars
export RADIX_APP_CNAME="grafana.$CLUSTER_NAME.$RADIX_ZONE_NAME"  # The CNAME you want to create an alias for
export RADIX_APP_ALIAS_NAME="grafana"                            # The name of the alias
export RADIX_APP_NAME="grafana"                                  # The name of the app in the cluster
export RADIX_NAMESPACE="default"                                 # Ovverided namespace
export RADIX_APP_COMPONENT="grafana"                             # The component which should receive the traffic
export RADIX_APP_COMPONENT_PORT="80"
