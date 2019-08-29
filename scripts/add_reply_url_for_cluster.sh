#!/bin/bash

# PURPOSE
# Add a replyURL to the input AAD app that handles the authentication for an app hosted in k8s.
# The script will generate the correct replyUrl to the app based on the app ingress host value, which is why the script also require input ingress name and namespace where the ingress can be found.

# Example 1:
# AAD_APP_NAME="Omnia Radix Web Console" K8S_NAMESPACE="radix-web-console-prod" K8S_INGRESS_NAME="web" REPLY_PATH="/auth-callback" ./add_reply_url_for_cluster.sh
# 
# Example 2: Using a subshell to avoid polluting parent shell
# (AAD_APP_NAME="radix-cluster-aad-server-dev" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" ./add_reply_url_for_cluster.sh)

# INPUTS:
#   AAD_APP_NAME            (Mandatory)
#   K8S_NAMESPACE           (Mandatory)
#   K8S_INGRESS_NAME        (Mandatory)
#   REPLY_PATH              (Mandatory)
#   SILENT_MODE             (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)

echo ""
echo "Updating replyUrls for AAD app \"${AAD_APP_NAME}\"..."

# Validate mandatory input
if [[ -z "$AAD_APP_NAME" ]]; then
    echo "Please provide AAD_APP_NAME."
    exit 1
fi
if [[ -z "$K8S_NAMESPACE" ]]; then
    echo "Please provide K8S_NAMESPACE."
    exit 1
fi
if [[ -z "$K8S_INGRESS_NAME" ]]; then
    echo "Please provide K8S_INGRESS_NAME."
    exit 1
fi
if [[ -z "$REPLY_PATH" ]]; then
    echo "Please provide REPLY_PATH."
    exit 1
fi

if [[ -z "$SILENT_MODE" ]]; then
    SILENT_MODE=false
fi

function updateReplyUrls() {
    local aadAppId
    local currentReplyUrls
    local host_name
    local additionalReplyURL

    aadAppId="$(az ad app list --display-name "${AAD_APP_NAME}" --query [].appId -o tsv)"
    # Convert list to string where urls are separated by space
    currentReplyUrls="$(az ad app show --id ${aadAppId} --query replyUrls --output json | jq -r '.[] | @sh')"
    # Remove tabs as mac really insist on one being there
    currentReplyUrls="$(printf '%s\t' ${currentReplyUrls})"
    host_name=$(kubectl get ing -n ${K8S_NAMESPACE} ${K8S_INGRESS_NAME} -o json| jq --raw-output .spec.rules[0].host)
    additionalReplyURL="https://${host_name}${REPLY_PATH}"  
    
    if [[ "$currentReplyUrls" == *"${additionalReplyURL}"* ]]; then
        echo "replyUrl \"${additionalReplyURL}\" already exist in AAD app \"${AAD_APP_NAME}\"."
        echo ""
        exit 0        
    fi

    local newReplyURLs
    newReplyURLs="${currentReplyUrls}'${additionalReplyURL}'"
   
    # Ask user
    echo "This will be the new list of replyUrls for AAD app $AAD_APP_NAME:"
    echo "$newReplyURLs"
    echo ""

    if [[ $SILENT_MODE != true ]]; then
        echo "Do you want to continue?"
        read -p "[Y]es or [N]o " -n 1 -r
        echo ""
        if [[ "$REPLY" =~ ^[Nn]$ ]]
        then
            echo "Skipping updating replyUrls."
            exit 0
        fi
    fi

    # Workaround for newReplyURLs param expansion
    local cmd_text
    cmd_text="az ad app update --id "${aadAppId}" --reply-urls "${newReplyURLs}""
    bash -c "$cmd_text"
   
    echo "Added replyUrl \"${additionalReplyURL}\" to AAD app \"${AAD_APP_NAME}\"."
    echo ""
}

### MAIN
 updateReplyUrls

