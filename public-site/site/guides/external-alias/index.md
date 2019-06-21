---
title: External Alias
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

# Introduction

It is possible to make an application available on a custom domain via a setting in `radixconfig.yaml`, provided you bring the corresponding certificate into Radix. 

## How to acquire a Equinor certificate

Request a certificate for your domain in the Services@Equinor portal - Service: Public SSL certificate. For this request you'll need a Certificate Signing Request (CSR) file. An example of how to create this file is using the `openssl` command as follows: 

1. Generate key  
   openssl genrsa -out e:\mydomain.equinor.com.key 2048  
2. Generate CSR  
   openssl req -new -key e:\mydomain.equinor.com.key -out e:\mydomain.equinor.com.csr  

Attach the csr file to the request  

In return you will receive a certificate file. The contents of this file, together with the private key in `mydomain.equinor.com.key` will be added as secrets to your application (see below). **Please note that the private key is sensitive information** and you must ensure it is stored safely (certainly **not** in a code repository).  

You should follow the appropriate procedure on how to handle keys and certificates.

## Configure external alias in `radixconfig.yaml`

A new configuration section needs to be added to the `radixconfig.yaml` file; for details see the documentation for the [`dnsExternalAlias` setting](../../docs/reference-radix-config/#dnsexternalalias) in the `radixconfig.yaml` file.

The application needs to be built and deployed for the applicable branch for the configuration to be applied.

## How to apply custom certificate to the application

Adding the certificate information to your application is done using the Radix Console.

Radix needs two pieces of information to enable the certificate for an external alias: the certificate itself, and the private key. These must be entered as secrets in the overview page of the component chosen as the target of the alias (in the appropriate environment).


![List of secrets for corresponding TLS certificate](list-of-external-alias-secrets.png "List of Secrets")

### Certificate 
Set the cert part of the TLS certificate and save. This is the content of the certificate file received at the end of the service request.


![Setting the cert part](setting-cert.png "Setting cert")

### Private key
Set the private key part of the TLS certificate and save. This is the content of the private key file that was used to generate the CSR.


![Setting the private key part](setting-private-key.png "Setting private key")

# What's next

The list of defined external aliases will be made available later.
