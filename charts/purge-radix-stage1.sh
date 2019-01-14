#!/bin/bash

# PURPOSE
# Do a complete delete and clean-up when deleting the "radix-stage1" helm chart.
# Some sub charts do not clean up properly which hinder later reinstall.
# This script will do it for them.

# First delete the main chart
helm delete --purge radix-stage1

# Remove CRDs that helm delete cert-man chart did not clean up
kubectl delete crd/certificates.certmanager.k8s.io
kubectl delete crd/clusterissuers.certmanager.k8s.io
kubectl delete crd/issuers.certmanager.k8s.io

# Done!
