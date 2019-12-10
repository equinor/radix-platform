# Flux

Please see [radix-flux](https://github.com/equinor/radix-flux/) for what, why and how we use flux.

## Bootstrap

Run script [`./bootstrap.sh`](./bootstrap.sh), see script header for more how.  

Bootstrap will
1. Read config repo credentials from keyvault
1. Install flux using the official helm chart
   - Config repo will by default be set to [radix-flux](https://github.com/equinor/radix-flux/)
   - Config branch will by default be set to `master`

Note that if you use the default repo then some of the components installed by flux expects certain prerequisite resources to exist in the cluster.  
The pre-req resources are normally created by the `install_base_components.sh` script.

### Examples

```sh
# Example: Bootstrap a debug cluster

# Step 1: bootstrap aks
RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=my-cluster-flux ../aks/bootstrap.sh
# Step 2: bootstrap helm
RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=my-cluster-flux ../helm/bootstrap.sh
# Step 3: bootstrap flux - note the use of GIT_BRANCH to point flux to my dev branch where I want to test deploy of some components that do not depend on any prerequisite radix resources
RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=my-cluster-flux GIT_BRANCH=my-fluxed-dev-branch ./bootstrap.sh
# Done!
```

## Teardown

Run script [`./teardown.sh`](./teardown.sh), see script header for more how.  

Teardown will
1. Delete flux and all related custom resources
1. Delete the repo credentials in the cluster
   -  It will _not_ touch the keyvault