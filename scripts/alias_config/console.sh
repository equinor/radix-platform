#!/bin/bash

# Set alias script vars
export RADIX_APP_CNAME="web-radix-web-console-prod.$CLUSTER_NAME.radix.equinor.com"  # The CNAME you want to create an alias for
export RADIX_APP_ALIAS_NAME="console"                                                # The name of the alias
export RADIX_APP_NAME="radix-web-console"                                            # The name of the app in the cluster
export RADIX_APP_COMPONENT="web"                                                     # The component which should receive the traffic
export RADIX_APP_COMPONENT_PORT="80"
