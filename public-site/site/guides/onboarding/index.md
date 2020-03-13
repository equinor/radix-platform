---
title: Onboarding
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

# General 

Basic understanding of some technologies are required for working efficient with Radix. 

For questions around topics covered in this section, its recommended to ask on slack and channel [developer_community](https://equinor.slack.com/archives/C3HLP8ZTQ). This is where the biggest number of people are ready to answer your questions.  

## git / github

A basic understanding of Git and Github is required to use Radix. [git - the simple guide](http://rogerdudler.github.io/git-guide/) is a good place to start.

## docker / containers

Even if your not using Radix, we would still recommend you to learn how to use Docker for containerization, and use it for hosting. It has many benefits when utilizing cloud.

[What is a container](https://www.youtube.com/watch?v=EnJ7qX9fkcU) and 
[Benefits of containers](https://www.youtube.com/watch?v=cCTLjAdIQho) are both good videos to explain what and why containers. 
[Best practice](https://www.radix.equinor.com/docs/topic-docker/) contains references to other relevant resources. 

## OAuth 2.0 - Authentication and Authorization

If your API needs to be protected and only accessible for a group of users, understanding of OAuth 2.0 is required. Again this is not bound to Radix, but general knowledge needed when hosting applications in Azure (and cloud). [Link](https://www.radix.equinor.com/guides/authentication/) can be a good place to start.

## Azure services

Other Azure services, as storage, is often needed together with Radix. 

# Radix

For questions around topics covered in this section, its recommended to ask on slack and channel [omnia_radix_support](https://equinor.slack.com/archives/CBKM6N2JY)

A good starting point for information around Radix is the [home page](https://www.radix.equinor.com/). An example on configuring an app can be found at the [site](https://www.radix.equinor.com/guides/configure-an-app/)

## Hosting/Infrastructure

In Radix we advocate [Infrastructure as code](https://en.wikipedia.org/wiki/Infrastructure_as_code) and more specifically declarative infrastructure. This is done through the radixconfig.yaml file where you define how you would like your application to be hosted. Documentation on radixconfig.yaml can be found at [link](https://www.radix.equinor.com/docs/reference-radix-config/). 

Radix is built on top of Kubernetes hosted on Azure as a service (AKS). Knowledge around Kubernetes is NOT required for using Radix. However thoughts from Kubernetes has influenced Radix, so it can be a good with some basic understanding of what it is. VMware has a 5min video on [youtube](https://www.youtube.com/watch?v=PH-2FfFD2PU), or for those more interested we can recommend [Introduction to Kubernetes](https://training.linuxfoundation.org/resources/free-courses/introduction-to-kubernetes/) course by linuxfoundation.


## CI / CD 

Radix provide a simple way to automatically build and deploy your application based on the [radixconfig.yaml](https://www.radix.equinor.com/docs/reference-radix-config/) file already mentioned. Alternatively, you can opt for using only the CD part of Radix. See [deploy only guide](../deploy-only/) on how set up your application for deploy-only.

## Monitoring

General information around [monitoring in Radix](https://www.radix.equinor.com/guides.html#monitoring) in Radix guides. When you work with an application, link to a basic monitoring dashboard is available on your apps first page, e.g. [ssdldpi](https://console.us.radix.equinor.com/applications/ssdldpi)
