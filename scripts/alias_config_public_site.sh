#!/bin/bash

# Set alias script vars
export RADIX_ZONE_NAME="radix.equinor.com"                                         # The name of the dns zone
export RADIX_APP_CNAME="public-site-radix-platform-prod.beta-3.radix.equinor.com"    # The CNAME you want to create an alias for
export RADIX_APP_ALIAS_NAME="www"                                                  # The name of the alias
export RADIX_APP_NAME="radix-platform"                                          # The name of the app in the cluster
export RADIX_APP_ENVIRONMENT="prod"                                                # The app environment in the cluster (ex: "prod", "qa", "test")
export RADIX_APP_COMPONENT="public-site"                                                   # The component which should receive the traffic
export RADIX_APP_COMPONENT_PORT="80"
export RADIX_HELM_REPO="radixprod"                                                 # The name of the helm repo which host the ingress chart. In ACR this is the name of the acr instance.
