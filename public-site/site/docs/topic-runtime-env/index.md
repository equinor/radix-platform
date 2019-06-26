---
title: Runtime environment
layout: document
parent: ["Docs", "../../docs.html"]
toc: true
---

Running an application in Radix is not much different to running Docker containers locally. However, you should be aware of some special behaviours and constraints.

# Networking

## Traffic

Only HTTPS traffic is allowed in and out of the application. SSL certificates are automatically managed by Radix, except for custom [external aliases](../../guides/external-alias/).

Internally, [components](../topic-concepts/#component) can communicate with each other using other protocols and [ports](../reference-radix-config/#components).

## Internal DNS

Communicating between components should be done using short DNS names. For instance, to access the `dataqueue` component from the `middleware` component, simply use the DNS name `dataqueue`. If this communication happens over HTTP, the internal URL to use would be `http://dataqueue`.

Other ports/protocols can be used, e.g. `fileserver:22` for an FTP port.

## Request size

For external requests there is an upload limit of 100MB. If your application need to receive larger payloads, these should be split across separate requests.

# Storage

Radix does not currently support persistent storage. Any files written to the filesystem will be lost when a component restarts or is redeployed. If you need persistence, cloud-based systems like [Azure storage](https://docs.microsoft.com/en-us/azure/storage/common/storage-introduction) are recommended.

# Running instances

Although you can configure the number of [replicas](../topic-concepts/#replica) for a component, Radix will occasionally run a different number of these. For instance, a component that has been configured to run with just one replica (this is the default) might momentarily have two replicas running during a Radix cluster migration.

This is a common characteristic of high-availability cloud-based environments. Your application should be written in a way that can cope with multiple running copies of a component, even if momentarily.
