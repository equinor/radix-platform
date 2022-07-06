#!/usr/bin/env bash

# PURPOSE
# Add a replyURL to the input AAD app that handles the authentication for an app hosted in k8s.
# The script will generate the correct replyUrl to the app based on the app ingress host value, which is why the script also require input ingress name and namespace where the ingress can be found.

# Example 1:
# AAD_APP_NAME="Omnia Radix Web Console" K8S_NAMESPACE="radix-web-console-prod" K8S_INGRESS_NAME="web" REPLY_PATH="/auth-callback" ./add_reply_url_for_cluster.sh
# 
# Example 2: Using a subshell to avoid polluting parent shell
# (AAD_APP_NAME="ar-radix-grafana-development" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" ./add_reply_url_for_cluster.sh)

# INPUTS:
#   AAD_APP_NAME            (Mandatory)
#   K8S_NAMESPACE           (Mandatory)
#   K8S_INGRESS_NAME        (Mandatory)
#   REPLY_PATH              (Mandatory)
#   USER_PROMPT             (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)

echo ""
echo "Updating replyUrls for AAD app \"${AAD_APP_NAME}\"..."

# Validate mandatory input
if [[ -z "$AAD_APP_NAME" ]]; then
    echo "ERROR: Please provide AAD_APP_NAME." >&2
    exit 1
fi
if [[ -z "$K8S_NAMESPACE" ]]; then
    echo "ERROR: Please provide K8S_NAMESPACE." >&2
    exit 1
fi
if [[ -z "$K8S_INGRESS_NAME" ]]; then
    echo "ERROR: Please provide K8S_INGRESS_NAME." >&2
    exit 1
fi
if [[ -z "$REPLY_PATH" ]]; then
    echo "ERROR: Please provide REPLY_PATH." >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Verify cluster access
###
verify_cluster_access

function updateRedirectUris() {
    local aadAppId
    local currentRedirectUris
    local host_name
    local additionalReplyURL
    local newRedirectUris

    aadAppId="$(az ad app list --display-name "${AAD_APP_NAME}" --only-show-errors --query [].appId -o tsv)"
    if [[ -z $aadAppId ]]; then
        echo "ERROR: Could not find app registration. Quitting..." >&2
        return 1
    fi
    # Convert list to string where urls are separated by space
    currentRedirectUris="$(az ad app show --id ${aadAppId} --query web.redirectUris --only-show-errors --output json | jq -r '.[] | @text')"

    host_name=$(kubectl get ing --namespace ${K8S_NAMESPACE} ${K8S_INGRESS_NAME} -o json| jq --raw-output .spec.rules[0].host)
    additionalReplyURL="https://${host_name}${REPLY_PATH}"

    if [[ "$currentRedirectUris" == *"${additionalReplyURL}"* ]]; then
        echo "replyUrl \"${additionalReplyURL}\" already exist in AAD app \"${AAD_APP_NAME}\"."
        echo ""
        return 0
    fi

    newRedirectUris="${currentRedirectUris} ${additionalReplyURL}"

    # Ask user
    echo "This will be the new list of Redirect URIs for AAD app $AAD_APP_NAME:"
    echo "${currentRedirectUris}"
    echo "${additionalReplyURL}"
    echo ""

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Do you want to continue? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) echo ""; echo "Skipping updating RedirectUris."; return 0;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    az ad app update \
        --id "${aadAppId}" \
        --web-redirect-uris ${newRedirectUris} \
        --only-show-errors ||
        { echo "ERROR: Could not update app registration." >&2; return 1; }

    echo "Added replyUrl \"${additionalReplyURL}\" to AAD app \"${AAD_APP_NAME}\"."
    echo ""
}

### MAIN
updateRedirectUris
