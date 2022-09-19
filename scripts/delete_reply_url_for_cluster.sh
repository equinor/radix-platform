#!/usr/bin/env bash

# PURPOSE
# Delete a replyURL from the input AAD app that handles the authentication for an app hosted in k8s.
# The script will delete the correct replyUrl from the app based on the app ingress host value, which is why the script also require input ingress name and namespace where the ingress can be found.

# Example 1:
# APP_REGISTRATION_ID="5687b237-eda3-4ec3-a2a1-023e85a2bd84" APP_REGISTRATION_OBJ_ID="eb9a6a59-d542-4e6d-b3f6-d5955d1b919a" REPLY_URL="https://auth-radix-web-console-qa.weekly-39-c.dev.radix.equinor.com/oauth2/callback" WEB_REDIRECT_URI="https://auth-radix-web-console-qa.weekly-39-c.dev.radix.equinor.coms" ./delete_reply_url_for_cluster.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (APP_REGISTRATION_ID="f545deb5-f721-4d20-87cd-b046b5119d70" REPLY_URL="https://grafana.weekly-39-c.dev.radix.equinor.com/login/generic_oauth" source "./delete_reply_url_for_cluster.sh")

# INPUTS:
#   APP_REGISTRATION_ID     (Mandatory)
#   APP_REGISTRATION_OBJ_ID (Mandatory)
#   REPLY_PATH              (Mandatory)
#   REPLY_PATH              (Optional)
#   USER_PROMPT             (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)

# Validate mandatory input
if [[ -z "$APP_REGISTRATION_ID" ]]; then
    echo "ERROR: Please provide APP_REGISTRATION_ID." >&2
    exit 1
fi
if [[ -z "$APP_REGISTRATION_OBJ_ID" ]]; then
    echo "ERROR: Please provide APP_REGISTRATION_OBJ_ID." >&2
    exit 1
fi
if [[ -z "$REPLY_URL" ]]; then
    echo "ERROR: Please provide REPLY_URL." >&2
    exit 1
fi
if [[ -z "$WEB_REDIRECT_URI" ]]; then
    RUN_updateSpaRedirectUris=false
    echo "WARNING: No WEB_REDIRECT_URI found will skip updateSpaRedirectUris"
else
    RUN_updateSpaRedirectUris=true
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

function deleteWebRedirectUris() {
    APP_REGISTRATION_NAME=$(az ad app show --id "${APP_REGISTRATION_ID}" --query displayName --output tsv --only-show-errors)
    if [[ -z $APP_REGISTRATION_NAME ]]; then
        echo "ERROR: Could not get app registration name. Quitting..." >&2
        exit 1
    fi

    echo ""
    echo "Deleting Web replyUrl for App Registration \"${APP_REGISTRATION_NAME}\"..."
    echo ""

    # Get a list of all replyUrls in the App Registration
    array=$(az ad app show --id "${APP_REGISTRATION_ID}" --query "web.redirectUris" --only-show-errors)

    if [[ $(echo ${array} | jq 'select(. | index("'${REPLY_URL}'"))') ]]; then
        if [[ $USER_PROMPT == true ]]; then
            while true; do
                read -r -p "Do you want to delete \"${REPLY_URL}\" from App Registration \"${APP_REGISTRATION_NAME}\"? (Y/n) " yn
                case $yn in
                [Yy]*)
                    echo ""
                    break
                    ;;
                [Nn]*) exit ;;
                *) echo "Please answer yes or no." ;;
                esac
            done
        fi
        uris=$(echo ${array} | jq -r 'del(.[] | select(. | index("'${REPLY_URL}'"))) | join (" ")')
        printf "Deleting Web replyUrl \"${REPLY_URL}\" from App Registration \"${APP_REGISTRATION_NAME}\"..."
        az ad app update --id "${APP_REGISTRATION_ID}" --web-redirect-uris ${uris} --only-show-errors
        printf " Done.\n"
    else
        echo "ERROR: Web ReplyUrl \"${REPLY_URL}\" not found in App Registration \"${APP_REGISTRATION_NAME}\"." >&2
    fi
}

function deleteSpaRedirectUris() {
    APP_REGISTRATION_NAME=$(az ad app show --id "${APP_REGISTRATION_OBJ_ID}" --query displayName --output tsv --only-show-errors)
    if [[ -z $APP_REGISTRATION_NAME ]]; then
        echo "ERROR: Could not get Spa app registration name. Quitting..." >&2
        exit 1
    fi

    echo ""
    echo "Deleting Spa replyUrl for App Registration \"${APP_REGISTRATION_NAME}\"..."
    echo ""

    currentSpaRedirectUris=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/applications/${APP_REGISTRATION_OBJ_ID}" | jq -r .spa.redirectUris)

    if [[ "$(echo "${currentSpaRedirectUris}" | jq -e ". | any(. == \"${WEB_REDIRECT_URI}\")")" == true ]]; then
        if [[ $USER_PROMPT == true ]]; then
            while true; do
                read -r -p "Do you want to delete \"${WEB_REDIRECT_URI}\" from App Registration \"${APP_REGISTRATION_NAME}\"? (Y/n) " yn
                case $yn in
                [Yy]*)
                    echo ""
                    break
                    ;;
                [Nn]*) exit ;;
                *) echo "Please answer yes or no." ;;
                esac
            done
        fi
        newSpaRedirectUris=$(echo "${currentSpaRedirectUris}" | jq ". -= [\"$WEB_REDIRECT_URI\"]")
        printf "Deleting Spa replyUrl \"${WEB_REDIRECT_URI}\" from App Registration \"%s\"..." "${APP_REGISTRATION_NAME}"
        az rest \
            --method PATCH \
            --uri "https://graph.microsoft.com/v1.0/applications/${APP_REGISTRATION_OBJ_ID}" \
            --headers "Content-Type=application/json" \
            --body "{\"spa\":{\"redirectUris\":${newSpaRedirectUris}}}"
        printf " Done.\n"
    else
        echo "ERROR: Spa ReplyUrl \"${WEB_REDIRECT_URI}\" not found in App Registration \"${APP_REGISTRATION_NAME}\"." >&2
    fi
}

### MAIN
deleteWebRedirectUris
if [[ $RUN_updateSpaRedirectUris == true ]]; then
    deleteSpaRedirectUris
fi
