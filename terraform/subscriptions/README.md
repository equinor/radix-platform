## Starting from scratch

### Prerequisites

- You must have the role `owner` for all the radix azure subscriptions to be able to create the required azure resources

### Bootstrap base infrastructure

## Network security perimeter

Each environment (except extmon) owns one network security perimeter,
`network-perimeter-<environment>`, with a shared `defaultProfile`. Every
association is `Enforced`; `Learning` and `Audit` are not supported. Association
names equal the name of the associated resource. Associations are declared in
the module that manages the resource, never in the environment root.

| Resource | Module | Association |
| --- | --- | --- |
| Config Key Vault (`radix-config-<env>`) | `base-infrastructure` | always, named `network-perimeter-<env>` |
| Main Key Vault (`radix-keyv-<env>`) | `key-vault` | when `network_security_perimeter_profile_id` is set |
| Log Analytics workspaces | `log-analytics` | only when `ampls_enabled` is true |
| Storage accounts (`radixlog<env>`, `radixvelero<env>`) | `storageaccount` | always |

### Log Analytics

`log-analytics` wraps `log-analytics-ampls`, which manages the workspace and
the AMPLS scoped service. Without AMPLS the workspace must stay reachable over
the internet, so the perimeter association is created only when
`ampls_enabled` is true. The module requires
`network_security_perimeter_profile_id`. Every workspace has a system-assigned
managed identity, which Azure requires for authenticated intra-perimeter access.

### Storage accounts

`storageaccount` wraps `storageaccount-only`, which manages the account,
network rules, diagnostics, backup, private endpoint, DNS record and lifecycle
policy. The wrapper adds the perimeter association and sets the account's
public network access to `SecuredByPerimeter` through `azapi_update_resource`,
because AzureRM < 5.5 only supports `Enabled`/`Disabled`; `storageaccount-only`
therefore ignores changes to `public_network_access_enabled`.
Every account has a system-assigned managed identity, which Azure requires for
authenticated intra-perimeter access between associated resources.

`storageaccount` requires AzureRM `>= 4.60.0, < 5.0.0` and `azapi >= 2.7.0`;
`storageaccount-only` requires AzureRM `>= 3.110.0, < 5.0.0`.

### Key Vaults

The base module associates the config Key Vault directly. The `key-vault`
module associates the main vault when `network_security_perimeter_profile_id`
is set; the base module always sets it.

### Extmon

Extmon has no perimeter. It calls `log-analytics-ampls`, `storageaccount-only`
and `key-vault` (without a profile ID) directly and gets no associations.

### Shared state accounts

`s940radixinfra` and `s941radixinfra` are not associated with a perimeter
through Terraform; their associations are managed manually.

### State migration

Existing UUID-suffixed associations created outside Terraform are replaced by
the named associations above. A resource can only have one association, so an
apply that creates a named association fails with
`Only 'Audit' mode can be selected for the second association pairing` until
the old one is deleted. The AzureRM provider records the association as
created even when Azure later fails it, which shows up as the same association
being planned for creation on every run.

`log-analytics` and `storageaccount` carry `moved` blocks for the resources
that previously lived directly in those modules and now live in the nested
`log-analytics-ampls` and `storageaccount-only` modules. They are no-ops for
states that have already been migrated and can be removed once every
environment has applied this change. Review the plan before applying.
