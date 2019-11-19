# Radix Zones

POC for US

Introduce the concept of radix zones.  
The use case is to create groupings of clusters where each group is identified by domain name, and where the "active" cluster in each group has control of the group/zone dns.   
This allow us to run radix fully (logical app urls etc) in each zone.

Examples:
- "dev.radix.equinor.com"
- "playground.equinor.com"
- "prod.equinor.com"
- "prod-us.radix.equinor.com"

A radix-zone is defined by a `radix_zone_*.env` config, which should hold all env vars necessary for the running most install/bootstrap scripts.

## Components

### Zone infrastructure

   Owns:
   - dns
   - container-registry
   - cluster

   External dependencies:
   - keyvault
   - resource-groups
   - azure ad apps

   Config:
   - radix_zone_x.env



