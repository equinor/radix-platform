---
title: Domain names
layout: document
parent: ["Docs", "../../docs.html"]
toc: true
---

There can be several domain names mapped to [application components](../topic-concepts/#component) in Radix. In general you will want to use the [public name](#public-name), but you should understand all options.

> Some domain names include a `clusterEnvNamepace` component. This varies depending on the type of cluster. In Radix there are three **cluster types**; these are the values for `clusterEnvNamepace` in each type:
>
> - prod (_blank_)
> - playground (`playground`)
> - dev (`dev`)

# Canonical name

```
[componentName]-[appName]-[envName].[clusterName].[clusterEnvNamepace].radix.equinor.com
```

The authoritative name for a specific component in a specific cluster. In general you don't want this since you want to access the **active cluster** — for that you need the [public name](#public-name). The _canonical name_ can be useful when debugging, however.

- Always allocated
- Automatically allocated
- One per component
- Never changes its target, even if cluster becomes active/inactive

Examples:

- `frontend-myapp-production.playground-92.playground.radix.equinor.com`
- `backend-myapp-production.playground-92.playground.radix.equinor.com`
- `serializer-oneapp-qa.prod-12.radix.equinor.com`

# Public name

```
[componentName]-[appName]-[envName].[clusterEnvNamepace].radix.equinor.com
```

Each cluster type has exactly one **active cluster**, which can change.

For instance, the Radix admins can have two `prod` clusters, `prod-27` and `prod-28` while performing a migration. Only one of those two will be the active cluster. At the end of the migration, `prod-28` becomes active and all traffic should be directed there.

The _public name_ always points to components in the active cluster, and is the domain name that should be publicised. It is also the domain name that has [SLA guarantees](../topic-sla/).

- Only allocated for **active clusters**
- Automatically allocated
- One per component

Examples:

- `frontend-myapp-production.playground.radix.equinor.com`
- `backend-myapp-production.playground.radix.equinor.com`
- `serializer-oneapp-qa.radix.equinor.com`

# App default alias

```
[appName].app.[clusterEnvNamepace].radix.equinor.com
```

The _app default alias_ is a convenience domain name to make it easier to publish and use your application. It points to a specific component and environment in your application, and allows a reasonable URL to be distributed to end-users without the hassle of setting up [external aliases](#external-alias).

- Only allocated for **active clusters**
- One per application
- [Defined in `radixconfig.yaml`](../reference-radix-config/#dnsappalias)

Examples:

- `myapp.app.playground.radix.equinor.com`
- `oneapp.app.radix.equinor.com`

# External alias

```
[whatever]
```

For ultimate customisation of your domain names, you can "bring your own" domain into Radix with an _external alias_. There is a [detailed guide](../../guides/external-alias/) on how to configure this.

- Only allocated for **active clusters**
- Multiple allowed per component
- [Defined in `radixconfig.yaml`](../reference-radix-config/#dnsexternalalias)
- Requires external DNS alias management
- Requires custom TLS certificate

Examples:

- `cowabunga.equinor.com`
- `cheap-domains-r-us.net`
- `go0gle.com`
