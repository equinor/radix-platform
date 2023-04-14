#!/usr/bin/env bash

function create-a-record() {
    local record_name=$1
    local ip_address=$2
    local rg=$3
    local zone_name=$4
    local ttl=$5
    existing_a_record=$(az network dns record-set a show \
        --name "$record_name" \
        --resource-group "$rg" \
        --zone-name "$zone_name" \
        --query name \
        --output tsv \
        2>/dev/null)
    if [[ $existing_a_record = "" ]]; then
        # Create "@" record
        az network dns record-set a add-record \
            --resource-group "$rg" \
            --zone-name "$zone_name" \
            --record-set-name "$record_name" \
            --ipv4-address "$ip_address" \
            --if-none-match \
            --ttl $ttl \
            2>&1 >/dev/null
        return
    else
        # Update "@" record
        az network dns record-set a update \
            --name "$record_name" \
            --resource-group "$rg" \
            --zone-name "$zone_name" \
            --set aRecords[0].ipv4Address="$ip_address" \
            2>&1 >/dev/null
        return
    fi
}
