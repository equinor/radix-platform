# Radix scripts for service principals and aad apps

This directory contains scripts for handling common use cases when dealing with service principals and aad apps.  
A library for the most used functions can be found in the [`lib_service_principal.sh`](lib_service_principal.sh) file.

_Credentials_  
All credentials should be stored in radix keyvault as json using the schema provided by the [`template-credentials.json`](template-credentials) file.  

_Bootstrap and teardown_  
Components that require service principals and/or aad apps should handle this is part of their bootstrap/teardown process.  


## Components

- Azure AD
- Azure AD service principal
- Azure AD app
- Azure key vault


## Prerequisites

User must have the Azure AD role "Application Developer" active in order to work with Azure AD.


## Use cases

### Bootstrap and teardown cluster service principals

- [`bootstrap.sh`](./bootstrap.sh)
- [`teardown.sh`](./teardown.sh)

Bootstrap and teardown are scoped to handle the bare minimum service principals to get a radix cluster up and running,  
- Cluster SP
- Container registry SP
- CICD SP
- DNS SP

For any other SP see the bootstrap/teardown scripts for the components that require service principals.


### Refresh credentials

Service principals and az ad apps are two related beasts that must handled slightly differently when refreshing their credentials.  
We also have separate processes for how to update credentials for a component versus updating credentials for AKS.


#### Refresh component service principals credentials


1. Decide if you need to refresh the service principal credentials in AAD  
   Multiple components may use the same service principal and refreshing credentials in AAD will impact all of them 
   - If yes to refresh credentials in AAD: 
     Refresh credentials in AAD and store them in keyvault by using script [`refresh_service_principal_credentials.sh`](./refresh_service_principal_credentials.sh)
1. Manually update the credentials in the clusters for the component that use it  
   Usually the easiest way to do this is 
   1. Run install base components script to update k8s secrets
   1. Delete all the running pods of the component so that k8s will redeploy them with updated k8s secret  
      Examples:
      - Delete all `external-dns` pods to refresh DNS credentials
      - Delete all `cert-manager` pods to refresh DNS credentials
      - Delete all `radix-operator` pods to refresh ACR/CICD credentials


#### Refresh component AAD app credentials

1. Decide if you need to refresh the AAD app credentials in AAD  
   Multiple components may use the same AAD app and refreshing credentials in AAD will impact all of them
   - If yes to refresh credentials in AAD: 
     Refresh credentials in AAD and store them in keyvault by using script [`refresh_aad_app_credentials.sh`](./refresh_aad_app_credentials.sh)
1. Manually update the credentials in the clusters for the component that use it  
   Usually the easiest way to do this is 
   1. Run install base components script to update k8s secrets
   1. Delete all the running pods of the component so that k8s will redeploy them with updated k8s secret


#### Refresh AKS credentials

1. Refresh credentials for 
   - Cluster service principal by using script [`refresh_service_principal_credentials.sh`](./refresh_service_principal_credentials.sh)
   - Cluster AD app for RBAC integration by using script [`refresh_aad_app_credentials.sh`](./refresh_aad_app_credentials.sh)
1. Update AKS credentials using script [`update_aks_credentials_in_cluster.sh`](./update_aks_credentials_in_cluster.sh)



## Troubleshooting

### Sticky "update aks credentials" session

At times the command `az aks update-credentials` can be very slow, most often due to azcli not being able to get a proper reply from the azure api.  
If you press `CTRL+C` while the terminal shows `- Running` then it will continue to the next step in the script and by so you can "massage" the process forward.  
The other, harder, option is to cancel the script, comment out the long running step in code and then rerun the script to get to the next steps.  
To verify that the operations have run then take a look in the activity log for the cluster you are working on.  
![Cluster activity log](./activity-log.PNG)

