#!/usr/bin/env bash

# This feature is enabled on az subscription level.
# https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/view-master-logs.md
# The script will first check required roles (and notify user if they cannot run the script),
# then it will perform the operation.

function checkPermissions() {
    local subName="$(az account show --query name -otsv)"
    local username="$(az account show --query user.name -otsv)"
    local roleNames="$(az role assignment list --include-groups --assignee ${username} --query [].roleDefinitionName)"

    echo ""
    echo "Checking permissions..."

    # Check for required roles
    local hasContributor="$(echo $roleNames | jq '.[] | index( "Contributor" ) // empty')"
    local hasOwner="$(echo $roleNames | jq '.[] | index( "Owner" ) // empty')"

    # Exist if user do not have required roles
    if [ -z "$hasContributor" ] && [ -z "$hasOwner" ]; then
        echo "ERROR: The user \"${username}\" require one of these roles" 2>&1
        echo "- \"Contributor\"" 2>&1
        echo "- \"Owner\"" 2>&1
        echo "in the subscription \"$subName\" to perform this operation." 2>&1
        echo "Exiting script." 2>&1
        exit 1
    fi
}

function enableAuditLog() {
    # 1. AKS only captures audit logs for clusters that are created or upgraded after a feature flag is enabled on your subscription
    echo "Starting registration"
    az feature register --name AKSAuditLog --namespace Microsoft.ContainerService

    # 2. Wait for the status to show Registered
    # az feature list -o json --query "[?contains(name, 'Microsoft.ContainerService/AKSAuditLog')].{Name:name,State:properties.state}"
    echo "Waiting for registration to complete. This might take several minutes..."
    local registrationState
    while sleep 5; do
        registrationState="$(az feature list -o tsv --query "[?contains(name, 'Microsoft.ContainerService/AKSAuditLog')].{Name:name,State:properties.state} | [0].State")"
        if [ "$registrationState" == "Registered" ]; then
            break
        else
            printf "."
        fi
    done

    # 3. When ready, refresh the registration of the AKS resource provider using the az provider register command
    # az provider register --namespace Microsoft.ContainerService
    az provider register --namespace Microsoft.ContainerService

    echo ""
    echo "Done!"
    echo ""
}

########################################################################
# MAIN
########################################################################
echo "So you want to enable AKS audit log for subscription: $(az account show --query name)."
checkPermissions
enableAuditLog
