---
title: External Alias
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

# Introduction

It is possible to make an application available on a custom domain via a setting in `radixconfig.yaml`, provided you bring the corresponding certificate into Radix. 

## How to aquire a Equinor certificate

Request a certificate for your domain in the Services@Equinor portal - Service: Public SSL certificate. For this request you'll need a CSR file. This can be created using the following instructions:  

1. Generate key  
   openssl genrsa -out e:\mydomain.equinor.com.key 2048  
2. Generate CSR  
   openssl req -new -key e:\mydomain.equinor.com.key -out e:\mydomain.equinor.com.csr  

Attach the csr file to the request  

In return you will receive a certificate, this together with the private key from the mydomain.equinor.com.key will be added as secrets to your application.  

## Configure external alias in Radix config

A new configuration section needs to be added to the `radixconfig.yaml`, for details see the documentation for the [`dnsExternalAlias` setting](../../docs/reference-radix-config/#dnsexternalalias) in the `radixconfig.yaml` file.

The application needs to be build and deployed for applicable branch for the configuration to be applied.

## How-to apply custom certificate to the application

Adding the certificate information to your application is done using the Radix Console

The TLS certificate consists of a certificate and a private key. Once the external alias has been defined, the secrets for the TLS certificate parts will be listed under secrets in the **applicable component overview** page.  


![List of secrets for corresponding TLS certificate](list-of-external-alias-secrets.png "List of Secrets")

### Certificate 
Set the cert part of the TLS certificate and save.  


![Setting the cert part](setting-cert.png "Setting cert")

### Private key
Set the private key part of the TLS certificate and save.  


![Setting the private key part](setting-private-key.png "Setting private key")

# What's next

The list of defined external aliases will be made available later.
