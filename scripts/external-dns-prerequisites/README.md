# External-dns

Support scripts for the third party component `external-dns`.

## Bootstrap prerequisites for external-dns

### Prereq 1: Service principal credentials for talking to the DNS Zone

1. The service principal credentials must be available in the radix-zone key vault
1. `external-dns` expects to read the credentials from a `azure.json` file
1. The cluster can give `external-dns` the credentials as a k8s secret with `azure.json` as payload

The bootstrap script will
1. Read SP credentials from key vault
1. Generate `azure.json` using the provided template `tempate-azure.json`
1. Create a k8s secret in the target cluster using the generated `azure.json` file as payload


## Refresh credentials

`external-dns` use dedicated service principal to work with the DNS.  
The name of this service principal is declared in var `AZ_SYSTEM_USER_DNS` in `radix_zone_*.env` config files

For updating/refreshing the credentials then 
1. Decide if you need to update the service principal credentials in AAD  
   Multiple components make use of this service principa and you only need to update AAD once, and then you can proceed to updating the credentials in the cluster for each component 
   - If yes in step 1: Refresh service principal credentials in AAD and update keyvault by following the instructions provided in doc ["service-principals-and-aad-apps/README.md"](../service-principals-and-aad-apps/README.md#refresh-component-service-principals-credentials)      
1. Update the credentials in the cluster by executing the component bootstrap script
1. Restart the `external-dns` pods so that the new replicas will read the updated k8s secrets
1. Done!