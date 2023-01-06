#!/usr/bin/env bash

# ACTION={checkin | checkout} ./sync.sh

if [[ -z "$ACTION" ]]; then
    echo "ERROR: Please provide ACTION" >&2
    exit 1
fi

hash azcopy 2>/dev/null || {
    echo -e "\nERROR: azcopy not found in PATH. Exiting..." >&2
    exit 1
}

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#echo "$WORKDIR_PATH"

if [[ ${ACTION} == "checkin" ]]; then
    # Exit if source cluster does not exist
    echo ""
    echo "Downloading terraform.state file..."
    azcopy copy 'https://s941radixinfra.blob.core.windows.net/tfstate/storageaccounts/terraform.tfstate' terraform.tfstate
    echo ""
elif [[ ${ACTION} == "checkout" ]]; then
    echo ""
    echo "Uploadring terraform.state file..."
    #azcopy copy terraform.state 'https://s941radixinfra.blob.core.windows.net/tfstate/storageaccounts/terraform.tfstate'
    azcopy copy terraform.tfstate 'https://s941radixinfra.blob.core.windows.net/infrastructure/storageaccounts/terraform.tfstate'
    echo ""
fi

