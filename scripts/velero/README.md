# Velero

Velero is a third party tool that we use for handling backup and restore of radix apps and related manifests in radix k8s clusters.  


## Table of contents

- [Components](#components)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Removal](#removal)
- [Credentials](#credentials)


Related repos:
- [Radix config repo](https://github.com/equinor/radix-flux)
- [Radix Velero plugin](https://github.com/equinor/radix-velero-plugin)

Related info:
- [Official Velero docs](https://heptio.github.io/velero)
- [Spike: Can we use Velero for disaster/recovery?](./spike-result.md)  
  - [Spike recovery](./spike-recovery.md)

Operations:
- [Velero operations](./operations.md)
- [Restore](./restore/)

Official docs:
- [Velero official docs](https://velero.io/docs/)  
- [Velero on GitHub](https://github.com/heptio/velero) 


## Components

- _Velero server_  
  - Runs in the cluster
  - Configuration is handled by velero custom resource definitions in radix flux repo
  - Install when creating a radix cluster  

- _Velero cli client_  
  - Runs locally
  - Installed as-needed for operations  

- _Azure blob storage_  
  - Store backups
  - Unique per cluster
  - Created when velero is installed in the cluster
  - Installed/removed once per environment using script  

- _Azure storage accoount_  
  - Controls the blob storage
  - Unique per infrastructure environment
  - Shared among all velero instances in the same infrastructure environment
  - Installed/removed once per environment using script  

- _Azure resource group_
  - Holds the blob storage
  - Limit outside access to backups
  - Limit access for velero to anything else as velero require Contributor access to the entire resource group
  - Unique per infrastructure environment
  - Shared among all velero instances in the same infrastructure environment
  - Installed/removed once per environment using script  

- _Azure service principal_  
  - System user for velero to access azure storage and resource group
  - Unique per infrastructure environment
  - Shared among all velero instances in the same infrastructure environment
  - Installed/removed once per environment using script
 

## Getting Started

### Prerequisites

- You must have the az role `Owner` for the az subscription that is the infrastructure environment
- Be able to run `bash` scripts (linux/macOs)
- `flux` must be running in the cluster
- The velero deployment manifest must be present in the radix-flux repo


#### Optional: Install local client

If you are going to work with/debug Velero then installing the local client is highly recommended.

```sh
# Linux
wget https://github.com/heptio/velero/releases/download/v1.0.0/velero-v1.0.0-linux-amd64.tar.gz
tar zxvf velero-v1.0.0-linux-amd64.tar.gz
sudo mv velero-v1.0.0-linux-amd64/velero /usr/bin/

# MacOs
brew install velero
```

If this does not work the see https://velero.io/docs/v1.0.0/get-started


## Deployment

A deployment of Velero comes in two parts:
1. Bootstrap Velero resources that are shared among all clusters in a radix environment (prod/dev)
   - A storage account for storing cluster backups
   - A service principal that can handle the cluster backups
1. Deploy Velero to a radix cluster
   1. [Install prerequisites in given cluster](./install_prerequisites_in_cluster.sh)
      - Create velero namespace
      - Upload service principal credenitals as a k8s secret
      - Create a blob storage container that will hold the backups for the target cluster
      - Create a configmap that hold the name of blob storage and account that can access it
   1. Flux will then deploy Velero to the cluster using the configmap to provide the cluster specific parameter values


### Bootstrap shared resources per radix environment

You only need to do this _once_ per environment.

```sh
# Clone repo and navigate to velero dir
git clone https://github.com/equinor/radix-platform
cd radix-platform/scripts/velero

# Install in DEV environment. See script header for more info on usage.
RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh
```

### Deploy velero to a radix cluster

Velero is deployed as part of the installation of [radix base components](../install_base_components.sh)  

#### How it works

Velero is deployed by flux and the deployment manifest is found in the [radix-flux repo](https://github.com/equinor/radix-flux)  
Radix _share_ flux manifests for all clusters in a radix zone. To be able to set cluster specific settings for a deployment handled by flux then we need to [prepare
some prerequisite resources in the cluster](./install_prerequisites_in_cluster.sh).  
Included in these prequisites is a configmap that hold the cluster specific info that Flux will use when deploying the velero manifest.


#### Troubleshooting

```sh
# DEBUGGING
# To see if manifest has been synced then run
kubectl get helmRelease -n velero
# When the helmRelease is present then this will trigger the flux-helm-operator to install the chart as specified in the helmRelease manifest
# To see status of the helm release then run
helm list --namespace velero
```

## Removal

### Remove from cluster

Manual way
```sh

#####################################################
# If you want to remove everything
#
# Deleting the namespace will also delete the flux helmRelease, which again trigger a helm delete --purge
kubectl delete namespace/velero
# Clean up that which is unfortunately not removed by helm delete
kubectl delete clusterrolebinding/velero
kubectl delete crds --selector=app.kubernetes.io/name=velero

```

### Remove shared resources

```sh
# Clone repo and navigate to velero dir
git clone https://github.com/equinor/radix-platform
cd radix-platform/scripts/velero

# Remove from DEV environment. See script header for more info on usage.
RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./teardown.sh
```

(Yes, this is the official way of changing between read only and read write according to Velero Slack)

>>Notes!  
This behaviour will change in version 1.1 when read/read-write will apply to the storage location rather than the server itself: https://github.com/heptio/velero/pull/1517

>> PS: If a restore has warnings (shown in `velero restore get`) they will not show up in the logs. You need to `velero restore describe backupname-1234` to view warnings (and probably errors).


## Credentials

`velero` use dedicated service principal to work with the azure storage account.  
The name of this service principal is declared in var `AZ_SYSTEM_USER_VELERO` in `radix_zone_*.env` config files.  
The velero pod read these credentials as a k8s secret where the payload is in a shell env format as defined by the (credentials template)[./template_credentials.env]

For updating/refreshing the credentials then 
1. Decide if you need to refresh the service principal credentials in AAD  
   Multiple components may use this service principal and refreshing credentials in AAD will impact all of them 
   - If yes to refresh credentials in AAD: 
     Refresh service principal credentials in AAD and update keyvault by following the instructions provided in doc ["service-principals-and-aad-apps/README.md"](../service-principals-and-aad-apps/README.md#refresh-component-service-principals-credentials)      
1. Update the credentials for `velero` in the cluster by 
   - (Normal usage) Executing the `..\install_base_components.sh` script as described in paragraph ["Deployment"](#deployment)
   - (Alternative for debugging) Run [install prerequisites in cluster](./install_prerequisites_in_cluster.sh) script
1. Restart the `velero` pods so that the new replicas will read the updated k8s secrets
1. Done!


## Operations


See [./operations.md](./operations.md)
