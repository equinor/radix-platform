# Base infrastructure for radix environments

Radix has two environments:
- "dev"
- "prod"

All radix-zones belong to one of these, and can share the same infrastructure in the same environment.  

There are two special radix-zones:
- "dev"
- "prod"
These two contain the base infrastructure for the corrensponding radix environments.  


## Components

- Resource groups
- Azure Keyvault
- Azure DNS Zone
- Azure Container Registry
- System users
  - Permissions for system users per resource
- AAD apps for RBAC integration
   - Cluster AAD app
   - Kubectl AAD app

## Bootstrap

`RADIX_ZONE_ENV=../radix_zone_dev.env ./bootstrap.sh`

### Manual steps

#### AD Apps

You need to ask an Azure AD Administrator to go the Azure portal an click the "Grant permissions" button for these apps.

#### DNS Zone

If the dns zone is set to be something else than "radix.equinor.com" then you must [manually add delegation](https://github.com/equinor/radix-private/blob/master/docs/infrastructure/dns.md#how-to-delegate-from-prod-to-dev-or-playground) from "radix.equinor.com" to the new dns zone.

## Teardown

`RADIX_ZONE_ENV=../radix_zone_dev.env ./teardown.sh`