# Radix AKS

Bootstrap and teardown of Azure Kubernetes Service instances for Omnia Radix.

## Components

- _AKS_
- _VNET_  
  Required for setting network security policy in AKS

## Getting Started

### Prerequisites

- You must have the Azure role `Owner` for the Azure subscription that is the infrastructure environment
- Be able to run `bash` scripts (linux/macOs)
- Make sure you are authenticated in the command line (`az login`)
- `cd aks`

### Configuration

Cluster configuration for each environment is set in `env` files. You can edit these prior to bootstrap, if you don't like the defaults.

- [`prod.env`](./prod.env)  
  Cluster config for production
- [`dev.env`](./dev.env)  
  Cluster config for development
- [`network.env`](./network.env)  
  Advanced network configuration, shared for all environments

### Bootstrap

```sh
# Bootstrap a radix cluster in DEV environment. See script header for more info on usage.
RADIX_ENVIRONMENT=dev CLUSTER_NAME=improved-hamster ./bootstrap.sh
```

### Teardown

```sh
# Remove a radix cluster from DEV environment. See script header for more info on usage.
RADIX_ENVIRONMENT=dev CLUSTER_NAME=bad-hamster ./teardown.sh
```

## Misc

If you need to enable AKS diagnostic logs then you have to set that manually via the Azure portal. For more information on how to do this please see https://github.com/equinor/radix-private/blob/master/docs/infrastructure/logging.md
