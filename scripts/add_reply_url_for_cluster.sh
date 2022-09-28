#!/usr/bin/env bash

# PURPOSE
# Add a replyURL to the input AAD app that handles the authentication for an app hosted in k8s.
# The script will generate the correct replyUrl to the app based on the app ingress host value, which is why the script also require input ingress name and namespace where the ingress can be found.

# Example 1:
# AAD_APP_NAME="Omnia Radix Web Console" K8S_NAMESPACE="radix-web-console-prod" K8S_INGRESS_NAME="web" REPLY_PATH="/auth-callback" WEB_REDIRECT_URI="/applications" ./add_reply_url_for_cluster.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (AAD_APP_NAME="ar-radix-grafana-development" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" ./add_reply_url_for_cluster.sh)

# INPUTS:
#   AAD_APP_NAME            (Mandatory)
#   K8S_NAMESPACE           (Mandatory)
#   K8S_INGRESS_NAME        (Mandatory)
#   REPLY_PATH              (Mandatory)
#   WEB_REDIRECT_URI        (Optional)
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
if [[ -z "$WEB_REDIRECT_URI" ]]; then
    RUN_updateSpaRedirectUris=false
    echo "INFO: No WEB_REDIRECT_URI found will skip updateSpaRedirectUris"
else
    RUN_updateSpaRedirectUris=true
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Source util scripts

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${script_dir}/utility/util.sh

#######################################################################################
### Verify cluster access
###
verify_cluster_access

function updateWebRedirectUris() {
    local aadAppId
    local currentRedirectUris
    local host_name
    local additionalWebReplyURL
    local newWebRedirectUris

    aadAppId="$(az ad app list --display-name "${AAD_APP_NAME}" --only-show-errors --query [].appId -o tsv)"
    if [[ -z $aadAppId ]]; then
        echo "ERROR: Could not find app registration. Quitting..." >&2
        return 1
    fi
    # Convert list to string where urls are separated by space
    currentRedirectUris="$(az ad app show --id "${aadAppId}" --query web.redirectUris --only-show-errors --output json | jq -r '.[] | @text')"

    host_name=$(kubectl get ing --namespace "${K8S_NAMESPACE}" "${K8S_INGRESS_NAME}" -o json| jq --raw-output .spec.rules[0].host)
    additionalWebReplyURL="https://${host_name}${REPLY_PATH}"

    if [[ "$currentRedirectUris" == *"${additionalWebReplyURL}"* ]]; then
        echo "Web replyUrl \"${additionalWebReplyURL}\" already exist in AAD app \"${AAD_APP_NAME}\"."
        echo ""
        return 0
    fi

    newWebRedirectUris="${currentRedirectUris} ${additionalWebReplyURL}"

    # Ask user
    echo "This will be the new list of Web Redirect URIs for AAD app $AAD_APP_NAME:"
    echo "${currentRedirectUris}"
    echo "${additionalWebReplyURL}"
    echo ""

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Do you want to continue? (Y/n) " yn
            case $yn in
            [Yy]*)
                echo ""
                break
                ;;
            [Nn]*)
                echo ""
                echo "Skipping updating Web RedirectUris."
                return 0
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi

    az ad app update \
        --id "${aadAppId}" \
        --web-redirect-uris ${newWebRedirectUris} \
        --only-show-errors ||
        {
            echo "ERROR: Could not update app registration." >&2
            return 1
        }

    echo "Added Web replyUrl \"${additionalWebReplyURL}\" to AAD app \"${AAD_APP_NAME}\"."
    echo ""
}

function updateSpaRedirectUris() {
    local aadObjId
    local currentSpaRedirectUris
    local host_name
    local additionalSpaReplyURI
    local newSpaRedirectUris

    aadObjId="$(az ad app list --display-name "${AAD_APP_NAME}" --only-show-errors --query [].id -o tsv)"
    if [[ -z $aadObjId ]]; then
        echo "ERROR: Could not find app registration. Quitting..." >&2
        return 1
    fi

    currentSpaRedirectUris=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/applications/${aadObjId}" | jq -r .spa.redirectUris)

    host_name=$(kubectl get ing --namespace "${K8S_NAMESPACE}" "${K8S_INGRESS_NAME}" -o json| jq --raw-output .spec.rules[0].host)
    additionalSpaReplyURI="https://${host_name}${WEB_REDIRECT_URI}"

    if [[ "$(echo "${currentSpaRedirectUris}" | jq -e ". | any(. == \"$additionalSpaReplyURI\")")" == true ]]; then
        echo "Spa replyUrl \"${additionalSpaReplyURI}\" already exist in AAD app \"${AAD_APP_NAME}\"."
        echo ""
        return 0
    fi

    newSpaRedirectUris=$(echo "${currentSpaRedirectUris}" | jq ". += [\"$additionalSpaReplyURI\"]")

    # Ask user
    echo "This will be the new list of Spa Redirect URIs for AAD app $AAD_APP_NAME:"
    echo "${newSpaRedirectUris}" | jq -r '.[] | @text'
    echo ""

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Do you want to continue? (Y/n) " yn
            case $yn in
            [Yy]*)
                echo ""
                break
                ;;
            [Nn]*)
                echo ""
                echo "Skipping updating SpaRedirectUris."
                return 0
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi

    az rest \
        --method PATCH \
        --uri "https://graph.microsoft.com/v1.0/applications/${aadObjId}" \
        --headers "Content-Type=application/json" \
        --body "{\"spa\":{\"redirectUris\":${newSpaRedirectUris}}}"

    echo "Added Spa replyUrl \"${additionalSpaReplyURI}\" to AAD app \"${AAD_APP_NAME}\"."
    echo ""
}

### MAIN
updateWebRedirectUris
if [[ $RUN_updateSpaRedirectUris == true ]]; then
    updateSpaRedirectUris
fi
