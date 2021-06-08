#!/bin/bash

#######################################################################################
### PURPOSE
###

# Register a web application monitor in Dynatrace which enables Real User Monitoring
# (RUM) for a specified radix application. Dynatrace will inject a <script> tag
# which will be used to monitor the user interaction of the application. 

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Dynatrace has been deployed
# - The web application has a web interface.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"
# - APP_URL             : Ex: "console.dev.radix.equinor.com"

# Optional:
# - DETECTION_RULE_PATTERN         : Ex: "console.dev.radix.equinor.com"                        default: APP_URL
# - DETECTION_RULE_MATCH_TARGET    : "URL" "DOMAIN"                                             default: "DOMAIN"
# - DETECTION_RULE_MATCH_TYPE      : "MATCHES" "CONTAINS" "BEGINS_WITH" "ENDS_WITH" "EQUALS"    default: "MATCHES"

#######################################################################################
### HOW TO USE
### 

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env APP_URL="console.dev.radix.equinor.com" ./register_monitor.sh

#######################################################################################
### START
###

echo ""
echo "Enable Real User Monitoring..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting..."
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting..."
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting..."
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$APP_URL" ]]; then
    echo "Please provide APP_URL" >&2
    exit 1
fi

# Optional inputs
if [[ -z "$DETECTION_RULE_PATTERN" ]]; then
    DETECTION_RULE_PATTERN=$APP_URL
fi

if [[ -z "$DETECTION_RULE_MATCH_TYPE" ]]; then
    DETECTION_RULE_MATCH_TYPE="MATCHES"
fi

if [[ -z "$DETECTION_RULE_MATCH_TARGET" ]]; then
    DETECTION_RULE_MATCH_TARGET="DOMAIN"
fi

echo -e ""
echo -e "Web app monitor registration details:"
echo -e ""
echo -e "   ------------------------------------------------------------------"
echo -e "   -  APP_URL                       : $APP_URL"
echo -e "   -  DETECTION_RULE_MATCH_TARGET   : $DETECTION_RULE_MATCH_TARGET"
echo -e "   -  DETECTION_RULE_MATCH_TYPE     : $DETECTION_RULE_MATCH_TYPE"
echo -e "   -  DETECTION_RULE_PATTERN        : $DETECTION_RULE_PATTERN"
echo -e "   ------------------------------------------------------------------"
echo ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
        echo ""
        echo "Quitting."
        exit 0
    fi
    echo ""
fi

# Get secrets: api-url and tenant-token from keyvault
DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
DYNATRACE_API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)

# Check if already enabled
CHECK_APP="$(curl --request GET \
    --url $DYNATRACE_API_URL/config/v1/applications/web \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --silent | jq -r '.values[] | select(.name=="'$APP_URL'").id')"

if [[ "$CHECK_APP" == "" ]]; then
    echo "Not registered"
else
    echo "Registered"
    # exit 0
fi

# Validate create monitor
JSON=`cat default_web_app_body.json | jq '. += {"name":"'$APP_URL'"}' | jq '.'`
VALIDATE_APP="$(curl --request POST \
    --url $DYNATRACE_API_URL/config/v1/applications/web/validator \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --header 'Content-Type: application/json' \
    --data "$JSON" \
    --silent \
    --write-out '%{http_code}' | jq -r)"

if [[ $VALIDATE_APP == 204 ]]; then
    echo "Validation successful."
    # Create monitor
    CREATE_APP="$(curl --request POST \
        --url $DYNATRACE_API_URL/config/v1/applications/web \
        --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
        --header 'Content-Type: application/json' \
        --data "$JSON" \
        --silent \
        --output /dev/null \
        --write-out '%{http_code}' | jq -r)"
    # echo "CREATE APP: $CREATE_APP"
    if [[ $CREATE_APP == 201 ]]; then
        echo "Successfully registered the monitor."
    else
        echo "Could not create monitor."
    fi
else
    echo "Validation for application failed: $VALIDATE_APP"
    exit 1
fi

# Check if detection rule already registered
CHECK_DETECTION_RULE="$(curl --request GET \
    --url $DYNATRACE_API_URL/config/v1/applicationDetectionRules \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --silent | jq -r '.values[] | select(.name=="'$APP_URL'").id')"

if [[ "$CHECK_DETECTION_RULE" == "" ]]; then
    echo "Rule not registered: $APP_URL"
else
    echo "Registered"
    exit 0
fi

# Get application identifier for the detection rule.
APPLICATION_IDENTIFIER="$(curl --request GET \
    --url $DYNATRACE_API_URL/config/v1/applications/web \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --silent | jq -r '.values[] | select(.name=="'$APP_URL'").id')"

if [[ "$APPLICATION_IDENTIFIER" == "" ]]; then
    echo "Web app not registered: $APP_URL"
    exit 1
else
    # Validate create detection rule
    JSON=`cat default_detection_rule_body.json |
        jq '. += {"applicationIdentifier":"'$APPLICATION_IDENTIFIER'"}' |
        jq '.filterConfig += {"pattern":"'$DETECTION_RULE_PATTERN'"}' |
        jq '.filterConfig += {"applicationMatchType":"'$DETECTION_RULE_MATCH_TYPE'"}' |
        jq '.filterConfig += {"applicationMatchTarget":"'$DETECTION_RULE_MATCH_TARGET'"}' |
        jq '.'`
    VALIDATE_RULE="$(curl --request POST \
        --url $DYNATRACE_API_URL/config/v1/applicationDetectionRules/validator \
        --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
        --header 'Content-Type: application/json' \
        --data "$JSON" \
        --silent \
        --write-out '%{http_code}' | jq -r)"

    if [[ $VALIDATE_RULE == 204 ]]; then
        echo "Validation successful."
        # Create detection rule
        CREATE_RULE="$(curl --request POST \
            --url $DYNATRACE_API_URL/config/v1/applicationDetectionRules \
            --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
            --header 'Content-Type: application/json' \
            --data "$JSON" \
            --output /dev/null \
            --silent \
            --write-out '%{http_code}' | jq -r)"
        if [[ $CREATE_RULE == 201 ]]; then
            echo "Successfully registered detection rule."
        else
            echo "Could not create detection rule."
        fi
    else
        echo "Validation for detection rule failed: $VALIDATE_RULE"
    fi
fi
