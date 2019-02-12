#!/bin/bash

# Example:
# ./add_reply_url_for_cluster.sh

# INPUTS:
#   APP_REGISTRATION            (Optional. Defaulted if omitted)

# Set default values for optional input
if [[ -z "$APP_REGISTRATION" ]]; then
    APP_REGISTRATION="Omnia Radix Web Console"
fi

APP_REGISTRATION_ID="$(az ad app list --display-name "Omnia Radix Web Console" --query [].appId -o tsv)"
replyURLs="$(az ad app show --id ${APP_REGISTRATION_ID} --query replyUrls --output tsv)"

WEB_CONSOLE_HOSTNAME=$(kubectl get ing -n radix-web-console-prod web -o json| jq --raw-output .spec.rules[0].host)

newReplyURLs="$(echo $replyURLs https://$WEB_CONSOLE_HOSTNAME/auth-callback)"
commandString="az ad app update --id ${APP_REGISTRATION_ID} --reply-urls $newReplyURLs"

bash -c "$commandString"