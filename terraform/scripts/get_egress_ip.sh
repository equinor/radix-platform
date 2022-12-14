#!/usr/bin/env bash

workdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
RADIX_PLATFORM_REPOSITORY_PATH="${workdir}/../.."

# Source util scripts
source "${RADIX_PLATFORM_REPOSITORY_PATH}"/scripts/utility/util.sh

function error_exit() {
    echo "$1" 1>&2
    exit 1
}

function check_deps() {
    test -f "$(which az)" || error_exit "az command not detected in path, please install it"
    test -f "$(which jq)" || error_exit "jq command not detected in path, please install it"
}

function parse_input() {
    eval "$(jq -r '@sh "
    CLUSTER_NAME=\(.CLUSTER_NAME)
    AZ_SUBSCRIPTION_ID=\(.AZ_SUBSCRIPTION_ID)
    AZ_IPPRE_OUTBOUND_NAME=\(.AZ_IPPRE_OUTBOUND_NAME)
    AZ_RESOURCE_GROUP_COMMON=\(.AZ_RESOURCE_GROUP_COMMON)
    "')"
    if [[ -z "${CLUSTER_NAME}" ]]; then export CLUSTER_NAME=none; fi
    if [[ -z "${AZ_SUBSCRIPTION_ID}" ]]; then export AZ_SUBSCRIPTION_ID=none; fi
    if [[ -z "${AZ_IPPRE_OUTBOUND_NAME}" ]]; then export AZ_IPPRE_OUTBOUND_NAME=none; fi
    if [[ -z "${AZ_RESOURCE_GROUP_COMMON}" ]]; then export AZ_RESOURCE_GROUP_COMMON=none; fi
}

function getEgressIp() {
    local egress_ip="$(
        get_cluster_outbound_ip \
            at \
            "${CLUSTER_NAME}" \
            "${AZ_SUBSCRIPTION_ID}" \
            "${AZ_IPPRE_OUTBOUND_NAME}" \
            "${AZ_RESOURCE_GROUP_COMMON}"
    )"
    echo "${egress_ip}"
    return
}

function produce_output() {
    # Create a JSON object and pass it back
    jq -n \
        --arg egress_ip "$(getEgressIp)" \
        '{"egress_ip":$egress_ip}'
}

# Main
check_deps
parse_input
produce_output
