#!/usr/bin/env bash

# PURPOSE
# Delete a replyURL from the input AAD app that handles the authentication for an app hosted in k8s.
# The script will delete the correct replyUrl from the app based on the app ingress host value, which is why the script also require input ingress name and namespace where the ingress can be found.

# Example 1:
# APP_REGISTRATION_ID="5687b237-eda3-4ec3-a2a1-023e85a2bd84" REPLY_URL="https://auth-radix-web-console-qa.weekly-39-c.dev.radix.equinor.com/oauth2/callback" ./delete_reply_url_for_cluster.sh
# 
# Example 2: Using a subshell to avoid polluting parent shell
# (APP_REGISTRATION_ID="f545deb5-f721-4d20-87cd-b046b5119d70" REPLY_URL="https://grafana.weekly-39-c.dev.radix.equinor.com/login/generic_oauth" source "./delete_reply_url_for_cluster.sh")

# INPUTS:
#   APP_REGISTRATION_ID     (Mandatory)
#   REPLY_PATH              (Mandatory)
#   USER_PROMPT             (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)

# Validate mandatory input
if [[ -z "$APP_REGISTRATION_ID" ]]; then
    echo "ERROR: Please provide APP_REGISTRATION_ID." >&2
    exit 1
fi
if [[ -z "$REPLY_URL" ]]; then
    echo "ERROR: Please provide REPLY_URL." >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

APP_REGISTRATION_NAME=$(az ad app show --id "${APP_REGISTRATION_ID}" --query displayName -o tsv)
if [[ -z $APP_REGISTRATION_NAME ]]; then
    echo "ERROR: Could not get app registration name. Quitting..." >&2
    exit 1
fi

echo ""
echo "Deleting replyUrl for App Registration \"${APP_REGISTRATION_NAME}\"..."

# Get a list of all replyUrls in the App Registration
array=($(az ad app show --id ${APP_REGISTRATION_ID} --query replyUrls --output json | jq -r '.[]'))
length=${#array[@]}

# Get the index number of the replyUrl we want to delete
for ((i=0; i<$length; i++)); do
    if [[ "${array[$i]}" = "${REPLY_URL}" ]]; then
        index="${i}"
    fi
done

if [[ -z $index ]]; then
    echo "ERROR: ReplyUrl \"${REPLY_URL}\" not found in App Registration \"${APP_REGISTRATION_NAME}\"." >&2
else
    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -p "Do you want to delete \"${REPLY_URL}\" from App Registration \"${APP_REGISTRATION_NAME}\"? " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
    printf "Deleting replyUrl \"${REPLY_URL}\" from App Registration \"${APP_REGISTRATION_NAME}\"..."
    az ad app update --id "${APP_REGISTRATION_ID}" --remove replyUrls ${index}
    printf " Done.\n"
fi
