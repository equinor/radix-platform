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

See script header for info on usage.

## Credentials

Each radix cluster require two sets of credentials
1. Cluster service principal  
   The name is declared in var `AZ_SYSTEM_USER_CLUSTER` in `radix_zone_*.env` config files
1. Azure AD app for rbac integration  
   The name is declared in var `AZ_RESOURCE_AAD_SERVER` in `radix_zone_*.env` config files

For updating/refreshing the credentials then please follow the instructions provided in doc ["service-principals-and-aad-apps/README.md"](../service-principals-and-aad-apps/README.md#refresh-aks-credentials)



## Misc

If you need to enable AKS diagnostic logs then you have to set that manually via the Azure portal. For more information on how to do this please see https://github.com/equinor/radix-private/blob/master/docs/infrastructure/logging.md
