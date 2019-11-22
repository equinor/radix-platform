# Velero

[Heptio Velero official docs](https://heptio.github.io/velero)  
[Velero on GitHub](https://github.com/heptio/velero)  

Velero is a third party tool that we use for handling backup and restore of radix apps and related manifests in radix k8s clusters.  


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


### Installing

#### Install local client

```sh
# Linux
wget https://github.com/heptio/velero/releases/download/v1.0.0/velero-v1.0.0-linux-amd64.tar.gz
tar zxvf velero-v1.0.0-linux-amd64.tar.gz
sudo mv velero-v1.0.0-linux-amd64/velero /usr/bin/

# MacOs
brew install velero
```

If this does not work the see https://velero.io/docs/v1.0.0/get-started

#### Install infrastructure per environment

```sh
# Clone repo and navigate to velero dir
git clone https://github.com/equinor/radix-platform
cd radix-platform/scripts/velero

# Install in DEV environment. See script header for more info on usage.
RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh
```

## Deployment

Velero is deployed as part of the installation of radix base components.

```sh
# Clone repo and navigate to script dir
git clone https://github.com/equinor/radix-platform
cd radix-platform/scripts

# Velero is managed by flux, but in order for flux to be able to install it using cluster specific settings then we need to 
# add these settings as prerequisites in the cluster before handing it over to flux.
# We can do this as part of installing/upgrading base components
RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="democluster-2" ./install_base_components.sh

# And now you just wait for flux to sync manifests from the config repo. This can take a couple of minutes.

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

### Remove infrastructure

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




## Operations


See [./operations.md](./operations.md)
