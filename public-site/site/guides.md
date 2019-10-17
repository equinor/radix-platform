---
title: Guides
layout: document
toc: true
---

# Get to know Radix

The basic requirements are covered in [Getting started](guides/getting-started/).

The most beginner-friendly way to get started is the [Configuring an app](guides/configure-an-app/) guide. You can also watch the [Introduction to Radix video](https://statoilsrm.sharepoint.com/portals/hub/_layouts/15/PointPublishing.aspx?app=video&p=p&chid=653b6223-6ef5-4e5b-8388-ca8c77da4c7a&vid=3a64412f-0227-489d-9fda-f5f9845aacae) 🎥 for a more visual overview.

We also have a collection of [scenarios](guides/scenarios/) that can be used as templates for new or existing projects.

# Building, deploying and managing the app

How should you set up Git branches and Radix environments? Read about [workflows](guides/workflows/) for an overview. A common strategy is to use [promotion](guides/deployment-promotion) to control how deployments end up in environments.

Builds in Radix are Docker builds! The [Docker builds](guides/docker/) guide has recommendations for creating good `Dockerfile`s that work well in the cloud ☁️

Radix will generate automatic domains with SSL certificates for your application, but you can also have [your own custom domains](guides/external-alias), as long as you bring your own certificate.

Another functionality available is the ability to [restart, stop and start a component](guides/component-start-stop-restart/), the feature is available on your app component page in the Web Console

# Authentication

There are no checkbox that automatically provide authentication for your application in Radix. However there is still several way to introduce it to new and existing applications, without to much work. The [Authentication](./guides/authentication/index.md) guide goes through the basic to get authentication going for a Client and API. 

# Monitoring

You can use monitoring "out of the box" (the link to Grafana is in the top-right corner of the [Web Console](https://console.radix.equinor.com)). But you will get the most value by implementing [monitoring relevant for your app](guides/monitoring).
