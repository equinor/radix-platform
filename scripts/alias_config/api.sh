#!/bin/bash

# Set alias script vars
export RADIX_APP_CNAME="server-radix-api-prod.$CLUSTER_NAME.radix.equinor.com"    # The CNAME you want to create an alias for
export RADIX_APP_ALIAS_NAME="api"                                                 # The name of the alias
export RADIX_APP_NAME="radix-api"                                                 # The name of the app in the cluster
export RADIX_APP_COMPONENT="server"                                               # The component which should receive the traffic
export RADIX_APP_COMPONENT_PORT="3002"
