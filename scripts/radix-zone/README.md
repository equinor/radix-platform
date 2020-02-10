# Radix Zones

A radix-zone is a grouping of clusters where each group is identified by domain name, and where the "active" cluster in each group has control of the group/zone dns.   
This allow us to run radix fully (logical app urls etc) in each radix-zone.

Examples:
- "dev.radix.equinor.com"
- "playground.equinor.com"
- "prod.equinor.com"
- "prod-us.radix.equinor.com"

A radix-zone is defined by a `radix_zone_*.env` config, which should hold all env vars necessary to be able to run radix install/bootstrap scripts.  


## Radix-zone infrastructure

Radix has two environments:
- "dev"
- "prod"

All radix-zones belong to one of these, and can share the same infrastructure in the same environment.  

There are two special radix-zones:
- "dev"
- "prod"  
These two contain the base infrastructure for the corrensponding radix environments. See [base-infrastructure](./base-infrastructure/README.md) for details.

Some radix-zones have additional infrastructure, typically the dns zone.  
The boostrap/teardown scripts for each radix-zone that require their own additional infrastructure can be found in the corrensponding `./{radix-zone-name}-infrastructure/` directory.


