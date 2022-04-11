#!/usr/bin/env bash
#
# PURPOSE
# delete old records belonging to old clusters which no longer exist
# NOTE: Current version is unfinished state
#
# USAGE
#
# To run this script from terminal:
# RADIX_ENVIRONMENT=aa CLUSTER_TYPE=dd ./delete_dns_entries.sh
#
# Example: Delete from dev
# RADIX_ENVIRONMENT="dev" ./delete_dns_entries.sh
#
# Example: Delete from playground
# RADIX_ENVIRONMENT="dev" CLUSTER_TYPE="playground" ./delete_dns_entries.sh
#
# RADIX_ENVIRONMENT                 (Mandatory. Example: prod|dev)
# CLUSTER_TYPE                      (Optional. Defaulted if omitted. ex: "production", "playground", "development")
# RESOURCE_GROUP                    (Optional. Example: common)
# DNS_ZONE                          (Optional. Example:e.g. radix.equinor.com|dev.radix.equinor.com|playground.radix.equinor.com)

#######################################################################################
### Validate mandatory input
###

if [[ -z "$RADIX_ENVIRONMENT" ]]; then
    echo "Please provide RADIX_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
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

    if [[ "$RADIX_ENVIRONMENT" != "prod" ]] && [ "$CLUSTER_TYPE" = "playground" ]; then
      DNS_ZONE="playground.$DNS_ZONE"
    elif [[ "$RADIX_ENVIRONMENT" != "prod" ]]; then
      DNS_ZONE="${RADIX_ENVIRONMENT}.${DNS_ZONE}"
    fi
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="common"
fi

#######################################################################################
### Ask user to verify inputs and az login
###

echo -e ""
echo -e "Start deleting of orphaned DNS records using the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e "   -  CLUSTER_TYPE                     : $CLUSTER_TYPE"
echo -e "   -  DNS_ZONE                         : $DNS_ZONE"
echo -e "   -  RESOURCE_GROUP                   : $RESOURCE_GROUP"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

while true; do
    read -p "Is this correct? (Y/n) " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo ""; echo "Please use 'az login' command to login to the correct account. Quitting."; exit 0;;
        * ) echo "Please answer yes or no.";;
    esac
done

printf "Getting list of aks clusters..."
CLUSTERS="$(az aks list | jq --raw-output -r '.[].name')"
printf " Done.\n"

printf "Get TXT records..."

TXT_RECORD_LIST=$(az network dns record-set txt list \
    --resource-group ${RESOURCE_GROUP} \
    --zone-name ${DNS_ZONE} \
    --query "[].{name:name,value:to_string(txtRecords[].value[0])}")

printf " Done.\n"

echo "Find TXT records not bound to a cluster..."

for record in $(echo $TXT_RECORD_LIST | jq -r '.[] | @base64'); do
    record_name=$(echo $record | base64 --decode | jq -r '.name')
    heritage=$(echo $record | base64 --decode | jq -r '.value' | sed 's/.*owner=\(.*\),external-dns\/resource.*/\1/')
    if [[ ${CLUSTERS[@]} != *"$heritage"* || -z $heritage ]]; then
        # Clusters list does not contain the heritage cluster or the heritage property is missing.
        # Delete TXT record. 
        echo "$heritage: delete $record_name"
        printf "Deleting: $record_name..."
        az network dns record-set txt delete --yes --resource-group ${RESOURCE_GROUP} --zone-name ${DNS_ZONE} --name $record_name
        printf " Done.\n"
    fi
done
echo "Done."

printf "Get A-records..."

A_RECORD_LIST=$(az network dns record-set a list \
    --resource-group ${RESOURCE_GROUP} \
    --zone-name ${DNS_ZONE} \
    --query "[].{name:name}")

printf " Done.\n"

EXCLUDE_LIST=(
    "@"
    "*.ext-mon"
)

echo "Find A records not bound to a TXT-record..."

for record in $(echo $A_RECORD_LIST | jq -r '.[] | @base64'); do
    record_name=$(echo $record | base64 --decode | jq -r '.name')
    if [[ $(echo $TXT_RECORD_LIST | jq -r '.[] | select(.name=="'$record_name'").name') != "$record_name" && ${EXCLUDE_LIST[@]} != *"$record_name"* ]]; then
        printf "Deleting: $record_name..."
        az network dns record-set a delete --yes --resource-group ${RESOURCE_GROUP} --zone-name ${DNS_ZONE} --name $record_name
        printf " Done.\n"
    fi
done

echo " Done."

echo ""
echo "Deleted orphaned DNSs"
