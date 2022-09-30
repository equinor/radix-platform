#!/usr/bin/env bash

#IFS=','
IPS=""
while IFS=, read -r field1 field2
do
    #echo "$field1 and $field2"
    result=$( ./checkip.pl $field1 /dev/null 2>&1 ) 
    if [[ -n $result ]]; then
    echo "Wrong on $field1"
    else
    echo "Adding $field1"
    IPS+="$field1,"
    fi
done < whitelist-development.csv
echo "$IPS" | sed 's/.$//'