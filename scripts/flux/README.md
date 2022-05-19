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

## Issues bootstrapping Flux

If you get an error saying `unable to clone 'ssh://git@github.com/equinor/radix-flux', error: ssh: handshake failed: knownhosts: key mismatch` this means that the file `~/.ssh/known_hosts` is missing a `ecdsa-sha2-nistp256` key for `github.com`

Run the following commands to fix this issue:
1. `ssh-keyscan -t ecdsa github.com >> ~/.ssh/known_hosts` adds the new github.com key
2. If you get a **duplicate key** warning, run `ssh-keygen -R 140.82.121.3` to remove the duplicate key

References:
- [https://github.blog/2021-09-01-improving-git-protocol-security-github/](https://github.blog/2021-09-01-improving-git-protocol-security-github/)
- [https://github.com/fluxcd/flux2/discussions/2097](https://github.com/fluxcd/flux2/discussions/2097)