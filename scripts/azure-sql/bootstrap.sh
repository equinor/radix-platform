#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create storage account for sql servers

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### HOW TO USE
###
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh

#######################################################################################
### Read inputs and configs
###

printf "Starting sql bootstrap...\n"

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

#######################################################################################
### Create storage account
###

SQL_LOGS_STORAGEACCOUNT_EXIST=$(az storage account list \
    --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
    --query "[?name=='$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS'].name" \
    --output tsv)

if [ ! "$SQL_LOGS_STORAGEACCOUNT_EXIST" ]; then
    printf "%s does not exists.\n" "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"

    printf "    Creating storage account %s" "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"
    az storage account create \
        --name "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS" \
        --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
        --location "$AZ_RADIX_ZONE_LOCATION" \
        --sku "Standard_LRS" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --only-show-errors
    printf "Done.\n"
else
    printf "    Storage account exists...skipping\n"
fi

MANAGEMENT_POLICY_EXIST=$(az storage account management-policy show \
    --account-name "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS" \
    --resource-group "$AZ_RESOURCE_GROUP_COMMON")

LIFECYCLE=7

POLICY_JSON="$(
    cat <<END
{
  "rules": [
      {
          "enabled": "true",
          "name": "sql-rule",
          "type": "Lifecycle",
          "definition": {
              "actions": {
                  "version": {
                      "delete": {
                          "daysAfterCreationGreaterThan": "$LIFECYCLE"
                      }
                  },
              },
              "filters": {
                  "blobTypes": [
                      "blockBlob"
                  ],
              }
          }
      }
  ]
}
END
)"

if [ -z "$MANAGEMENT_POLICY_EXIST" ]; then
    printf "Storage account %s is missing policy\n" "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"

    if az storage account management-policy create \
        --account-name "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS" \
        --policy "$(echo "$POLICY_JSON")" \
        --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
        --only-show-errors; then
        printf "Successfully created policy for %s\n" "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"
    fi
else
     printf "    Storage account has policy...skipping\n"
fi

printf "Done.\n"
