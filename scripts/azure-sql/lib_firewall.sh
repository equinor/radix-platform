#!/usr/bin/env bash

add_local_computer_sql_firewall_rule() {
    server=$1
    resourceGroup=$2
    ruleName=$3

    myip=$(curl http://ifconfig.me/ip) || 
    { echo "ERROR: Failed to get IP address." >&2; return 1; }

    az sql server firewall-rule create \
        --end-ip-address $myip \
        --start-ip-address $myip \
        --name ${ruleName} \
        --resource-group $resourceGroup \
        --server $server \
        --output none \
        --only-show-errors ||
        { echo "ERROR: Failed to create firewall rule $ruleName." >&2; return 1; }
}

delete_sql_firewall_rule() {
    server=$1
    resourceGroup=$2
    ruleName=$3

    az sql server firewall-rule delete \
        --name ${ruleName} \
        --resource-group $resourceGroup \
        --server $server \
        --output none \
        --only-show-errors ||
        { echo "ERROR: Failed to delete firewall rule $ruleName." >&2; return 1; }
}