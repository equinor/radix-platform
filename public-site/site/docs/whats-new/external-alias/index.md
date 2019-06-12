---
title: External Alias
layout: document
parent: ["Docs", "../../../docs.html"]
toc: true
---

# Introduction

We have introduced a new configuration in the `radixconfig.yaml` file for having user defined aliases, provided developers bring the corresponding certificate. For information on how to configure that, see the documentation for the [`dnsExternalAlias` setting](../../reference-radix-config/#dnsexternalalias) in the `radixconfig.yaml` file.

# How-to set certificate

The TLS certificate consists of a cert part and a private key. Once the external alias has been defined, the secrets for the TLS certificate parts will be listed as secrets on the component.

![List of secrets for corresponding TLS certificate](list-of-external-alias-secrets.png "List of Secrets")

Set the cert part of the TLS certificate and save.

![Setting the cert part](setting-cert.png "Setting cert")

Set the private key part of the TLS certificate and save.

![Setting the private key part](setting-cert.png "Setting private key")

# Whats next

We will do some work to list the defined external aliases in a future feature.
