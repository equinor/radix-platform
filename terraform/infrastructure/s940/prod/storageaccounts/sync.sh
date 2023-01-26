#!/usr/bin/env bash

# ACTION={checkin | checkout} ./sync.sh

if [[ -z "$ACTION" ]]; then
    echo "ERROR: Please provide ACTION" >&2
    exit 1
fi

hash azcopy 2>/dev/null || {
    echo "ERROR: azcopy not found in PATH. Exiting..." >&2
    exit 1
}

if [[ ${ACTION} == "checkin" ]]; then
    # Exit if source cluster does not exist
    echo ""
    echo "Downloading terraform.state file..."
    azcopy copy 'https://s940radixinfra.blob.core.windows.net/tfstate/storageaccounts/terraform.tfstate' terraform.tfstate
    echo ""
elif [[ ${ACTION} == "checkout" ]]; then
    echo ""
    echo "Uploading terraform.state file..."
    azcopy copy terraform.tfstate 'https://s940radixinfra.blob.core.windows.net/tfstate/storageaccounts/terraform.tfstate'
    echo ""
fi
