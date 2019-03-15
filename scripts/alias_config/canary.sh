#!/bin/bash

# Set alias script vars
export RADIX_APP_CNAME="www-radix-canary-golang-prod.$CLUSTER_NAME.$RADIX_ZONE_NAME"    # The CNAME you want to create an alias for
export RADIX_APP_ALIAS_NAME="canary"                                                    # The name of the alias
export RADIX_APP_NAME="radix-canary-golang"                                             # The name of the app in the cluster
export RADIX_APP_COMPONENT="www"                                                        # The component which should receive the traffic
export RADIX_APP_COMPONENT_PORT="5000"
