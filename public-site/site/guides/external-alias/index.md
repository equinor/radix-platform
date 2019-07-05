---
title: External Alias
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

It is possible to make an application available on a custom domain via a setting in `radixconfig.yaml`, provided you register the domain and bring the corresponding TLS certificate into Radix.

You must register and make your domain name an alias of the [public name](../../docs/topic-domain-names/#public-name) of a component in your app. (Don't point an external alias at a canonical name.)

The process for setting up the alias depends on the service used to register and manage the domain name. This guide assumes registration of a `*.equinor.com` subdomain, but you should be able to adapt the instructions to a third-party provider.

# Acquire an Equinor subdomain alias

Request a DNS alias in the [Services@Equinor](https://equinor.service-now.com) portal (service: "IT infrastructure operational tasks"). Specify which [public name](../../docs/topic-domain-names/#public-name) the alias should point to. An example request:

```
New alias: myapp.equinor.com
Point to: frontend-myapp-prod.radix.equinor.com
```

# Acquire an Equinor certificate

Request a certificate for your domain in the [Services@Equinor](https://equinor.service-now.com) portal (service: "Public SSL certificate"). You'll need a Certificate Signing Request (CSR) file. To create a CSR file you need a private key. An example of how to create these files is to use the `openssl` command:

1. Generate private key

    ```shell
    openssl genrsa -out ./mydomain.equinor.com.key 2048
    ```

    Keep this file safe and out of version control. You will need it later.

2. Generate CSR file

    ```shell
    openssl req -new -key ./mydomain.equinor.com.key -out ./mydomain.equinor.com.csr
    ```

Attach the CSR file (not the private key) to the request. In return you will receive a certificate file. The contents of this file, together with the private key in `mydomain.equinor.com.key` will be added as secrets to your application (see below).

**The private key is sensitive information** and you must ensure it is stored safely (certainly **not** in a code repository). You should follow the appropriate procedure on how to handle keys and certificates.

# Edit `radixconfig.yaml`

You must add a new `dnsExternalAlias` section to the `radixconfig.yaml` file; check the [reference documentation](../../docs/reference-radix-config/#dnsexternalalias) for the details.

The application must be built and deployed for the configuration to be applied.

# Apply custom certificate

Adding the certificate information to your application is done using the Radix Console.

Radix needs two pieces of information to enable the certificate for an external alias: the certificate itself, and the private key. These must be entered as [secrets](../../docs/topic-concepts#secret) in the page of the component chosen as the target of the alias (in the appropriate environment). The two secrets will be named `<domain-name>-cert` and `<domain-name>-key`.

![List of secrets for corresponding TLS certificate](list-of-external-alias-secrets.png "List of Secrets")

## `<domain-name>-cert` secret

Paste the content of the certificate file you received.

![Setting the cert part](setting-cert.png "Setting cert")

## `<domain-name>-key` secret

Paste the content of the private key file that you generated at the start of the process.

![Setting the private key part](setting-private-key.png "Setting private key")

# What's next

Once the secrets are saved the custom aliases should start working. (The Web Console doesn't presently report those domains.)
