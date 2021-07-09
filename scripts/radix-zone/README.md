# Radix zones

A radix-zone is a grouping of clusters where each group is identified by domain name, and where the "active" cluster in each group has control of the group/zone dns.   
This allow us to run radix fully (logical app urls etc) in each radix-zone.  

Examples:

| radix-zone | domain |
| ---------- | ------ |
| prod |  radix.equinor.com |
| dev |  dev.radix.equinor.com |
| playground |  playground.radix.equinor.com |

## Radix-zone infrastructure

Radix has two _infrastructure_ environments that together hold the base infrastructure components for all other radix-zones:
- `dev`
- `prod`

All radix-zones belong to one of these environments.  
They can share the infrastructure components in that environment in addition to having their own dedicated resources like a dns zone that controls the unique radix-zone domain.  
The top radix domain is `radix.equinor.com` and it is controlled by the dns zone in `prod`. All other radix domains are delegated from this top domain.  

Examples:  
| radix-zone | infrastructure environment | radix-zone infrastructure components | shared infrastructure components |
| ---------- | -------------------------- | --------------------------------------------- | -------------------------------- |
| dev        | dev                        | dns zone | ACR, RBAC AAD app, "clusters" resource group, etc |
| playground | dev                        | dns zone | ACR, RBAC AAD app, "clusters" resource group, etc |


## Configuration

Each radix-zone is defined by a config file in the form of a bash shell env var file, `radix_zone_{name}.env`  
This config should hold all env vars necessary to be able to run all radix provisioning scripts (bootstrap, teardown, etc) in that radix-zone.  

Those radix-zones that require their own infrastructure components also have their own infrastructure bootstrap and teardown bash scripts.  
These scripts should be stored in a directory which name correnspond with the radix-zone, `./{name}-infrastructure/`  
Note that the scripts should be idempotent. Any change in infrastructure should be managed by updating and rerunning the scripts.

Example radix-zone "playground":  
- Config: [`radix_zone_playground.env`](./radix_zone_playground.env)
- Infrastructure scripts:  
  - [`./playground-infrastructure/bootstrap.sh`](./playground-infrastructure/bootstrap.sh)
  - [`./playground-infrastructure/teardown.sh`](./playground-infrastructure/teardown.sh)


## Starting from scratch

### Prerequisites

- You must have the role `owner` for all the omnia radix azure subscriptions to be able to create the required azure resources

### Bootstrap base infrastructure

See [base-infrastructure/README](./base-infrastructure/README.md) for instructions on how to perform each step.

1. Bootstrap radix-zone `prod` as this will also bootstrap infrastructure environment `prod`       
1. Bootstrap radix-zone `dev` as this will also bootstrap infrastructure environment `dev` 
1. Delegate domain `dev.radix.equinor.com` from dns zone in `prod` to dns zone in `dev`
1. Done!

You can now continue bootstrapping additional radix-zones, or bootstrap radix clusters in either radix-zone `dev` or `prod`.


## How to configure a new radix-zone

### Prerequisites  

- The radix-zones `prod` and `dev`, and their corrensponding infrastructure, must be available
- You must have the role `owner` for the azure subscription that will host the radix-zone to be able to create the required azure resources
- You must be able to delegate domain from the `prod` dns zone

### Workflow

1. Create the radix-zone config file, `radix_zone_{name}.env`
   - Use the infrastructure environment `dev` while developing and testing the radix-zone scripts
1. Create a directory that will hold the infrastructure scripts, `./{name}-infrastructure/`
1. Create the bootstrap script for radix-zone specific infrastructure components, `./{name}-infrastructure/bootstrap.sh`  
   The minimum is to bootstrap the dns zone and permissions to use it.  
   Pay attention to prefixing any other azure resource names as they must be unique and easy to identify that they belong to the radix-zone.
1. Create the teardown script for radix-zone specific infrastructure components, `./{name}-infrastructure/teardown.sh`  
   This script should remove everything that was created or configured by the bootstrap script
1. QA the bootstrap script
   - Verify that the script is idempotent by running it multiple times, you should end up with the exact same configuration
   - Verify that bootstrapping the radix-zone does not impact any other radix-zone
   - Verify that radix cluster(s) can run inside the radix-zone
     - Tear down these test clusters when done
1. QA the teardown script  
   Prereq: Tear down any radix clusters related to the radix-zone
   - Verify that the script is idempotent by running it multiple times, you should end up with the exact same configuration, and anything set up by bootstrap is gone
   - Verify that tear down of the radix-zone does not impact any other radix-zone
1. Done!