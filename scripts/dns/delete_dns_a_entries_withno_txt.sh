#!/bin/bash
#
# PURPOSE
# delete A records with no corresponding TXT record
# NOTE: Current version is unfinished state
#
# USAGE
#
# To run this script from terminal:
# SUBSCRIPTION_ENVIRONMENT=aa CLUSTER_TYPE=dd ./delete_dns_a_entries_withno_txt.sh
#
# Example: Delete from dev
# SUBSCRIPTION_ENVIRONMENT="dev" ./delete_dns_a_entries_withno_txt.sh
#
# Example: Delete from playground
# SUBSCRIPTION_ENVIRONMENT="dev" CLUSTER_TYPE="playground" ./delete_dns_a_entries_withno_txt.sh
#
# SUBSCRIPTION_ENVIRONMENT         (Mandatory. Example: prod|dev)
# CLUSTER_TYPE                     (Optional. Defaulted if omitted. ex: "production", "playground", "development")
# RESOURCE_GROUP                   (Optional. Example: common)
# DNS_ZONE                         (Optional. Example:e.g. radix.equinor.com|dev.radix.equinor.com|playground.radix.equinor.com)

#######################################################################################
### Validate mandatory input
###

if [[ -z "$SUBSCRIPTION_ENVIRONMENT" ]]; then
    echo "Please provide SUBSCRIPTION_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

#######################################################################################
### Set default values for optional input
###

if [[ -z "$CLUSTER_TYPE" ]]; then
    CLUSTER_TYPE="development"
fi

if [[ -z "$DNS_ZONE" ]]; then
    DNS_ZONE="radix.equinor.com"

    if [[ "$SUBSCRIPTION_ENVIRONMENT" != "prod" ]] && [ "$CLUSTER_TYPE" = "playground" ]; then
      DNS_ZONE="playground.$DNS_ZONE"
    elif [[ "$SUBSCRIPTION_ENVIRONMENT" != "prod" ]]; then
      DNS_ZONE="${SUBSCRIPTION_ENVIRONMENT}.${DNS_ZONE}"
    fi
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="common"
fi

#######################################################################################
### Ask user to verify inputs and az login
###

# Print inputs
echo -e ""
echo -e "Start deploy of base components using the following settings:"
echo -e "SUBSCRIPTION_ENVIRONMENT: $SUBSCRIPTION_ENVIRONMENT"
echo -e "CLUSTER_TYPE            : $CLUSTER_TYPE"
echo -e "DNS_ZONE                : $DNS_ZONE"
echo -e "RESOURCE_GROUP          : $RESOURCE_GROUP"
echo -e ""

# Check for Azure login
echo "Checking Azure account information"

AZ_ACCOUNT=`az account list | jq ".[] | select(.isDefault == true)"`
echo -n "You are logged in to subscription "
echo -n $AZ_ACCOUNT | jq '.id'
echo -n "Which is named " 
echo -n $AZ_ACCOUNT | jq '.name'
echo -n "As user " 
echo -n $AZ_ACCOUNT | jq '.user.name'
echo ""

read -p "Is this correct? (Y/n) " correct_az_login
if [[ $correct_az_login =~ (N|n) ]]; then
    echo "Please use 'az login' command to login to the correct account. Quitting."
    exit 1
fi

while read -r line; do
    if [[ "$line" ]]; then
        stringarray=($line)
        TXT_RECORD_EXISTS=$(az network dns record-set txt show -g ${RESOURCE_GROUP} -z ${DNS_ZONE} -n ${stringarray[1]} 2>&1)

        if [[ ""${TXT_RECORD_EXISTS}"" == *"Not Found"* ]]; then
            $(az network dns record-set a delete -y -g ${RESOURCE_GROUP} -z ${DNS_ZONE} -n ${stringarray[1]})
            echo "Deleted ${stringarray[1]}"
        fi

        echo "Done checking ${stringarray[1]}"
    fi
done <<< "$(az network dns record-set list --resource-group ${RESOURCE_GROUP} --zone-name ${DNS_ZONE} --query "[?type=='Microsoft.Network/dnszones/A']" | jq --raw-output -r '.[] | .id + " " + .name')"