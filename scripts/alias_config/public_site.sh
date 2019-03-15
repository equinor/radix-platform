#!/bin/bash

# Set alias script vars
export RADIX_APP_CNAME="public-site-radix-platform-prod.$CLUSTER_NAME.$RADIX_ZONE_NAME"    # The CNAME you want to create an alias for
export RADIX_APP_ALIAS_NAME="www"                                                          # The name of the alias
export RADIX_APP_NAME="radix-platform"                                                     # The name of the app in the cluster
export RADIX_APP_COMPONENT="public-site"                                                   # The component which should receive the traffic
export RADIX_APP_COMPONENT_PORT="80"
