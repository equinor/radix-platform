## Starting from scratch

### Prerequisites

- You must have the role `owner` for all the radix azure subscriptions to be able to create the required azure resources

### Bootstrap base infrastructure

### Network security perimeter associations

Each environment keeps its own perimeter and shared `defaultProfile`. Association
resources belong to the module that manages the associated resource, not the
environment root.

The `log-analytics` module requires the shared perimeter profile ID:

```hcl
network_security_perimeter_profile_id = module.base.network_security_perimeter_profile_id
```

It always creates one association using `workspace_name` and `Enforced` mode,
without `count` or `for_each`. The shared `log-analytics-ampls` module manages
the workspace and AMPLS link. Extmon uses it directly, without an association,
while other environments use it through `log-analytics`.
Existing UUID-suffixed workspace associations are intentionally replaced.

The `storageaccount` module always creates one association without `count` or
`for_each`, named after the storage account (e.g. `radixlogdev`). It requires
`network_security_perimeter_profile_id`. Existing UUID-suffixed associations are
intentionally replaced. The module also sets the account's public network access to
`SecuredByPerimeter` through `azapi_update_resource`, since AzureRM < 5.5 only
supports `Enabled`/`Disabled`; `storageaccount-only` therefore ignores changes
to `public_network_access_enabled`.
The shared `storageaccount-only` module manages the storage account, diagnostics,
backup, private endpoint and lifecycle policy. Extmon uses it directly without
an association. Existing `.data` outputs remain unchanged.
Both modules require AzureRM >= 4.60.0 and < 5.0.0.

The base module always manages one config Key Vault association named using
`network_security_perimeter_name`. This intentionally replaces existing
UUID-suffixed config Key Vault associations; the vault and perimeter are not
renamed.

The `key-vault` module associates the main vault (e.g. `radix-keyv-dev`) with the
perimeter when `network_security_perimeter_profile_id` is set; the association is
named after the vault. The base module always sets the profile ID; extmon calls
`key-vault` without it and gets no association.

All perimeter associations use `Enforced` access mode; there is no option for
`Learning` or `Audit`.

The shared state accounts (`s940radixinfra` / `s941radixinfra`) are
intentionally not associated with a perimeter through Terraform; their
associations are managed manually.

The module-address migrations have been applied in dev, playground, c2, c3 and
prod, and their `moved` and `import` blocks have been removed. Existing states
must use the current module addresses. Review the plan before applying.