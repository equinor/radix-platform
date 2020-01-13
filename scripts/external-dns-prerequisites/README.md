# Bootstrap prerequisites for external-dns

## Prereq 1: Service principal credentials for talking to the DNS Zone

1. The service principal credentials must be available in the radix-zone key vault
1. `external-dns` expects to read the credentials from a `azure.json` file
1. The cluster can give `external-dns` the credentials as a k8s secret with `azure.json` as payload

The bootstrap script will
1. Read SP credentials from key vault
1. Generate `azure.json` using the provided template `tempate-azure.json`
1. Create a k8s secret in the target cluster using the generated `azure.json` file as payload
