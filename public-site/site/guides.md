---
title: Guides
layout: document
toc: true
---

# Get to know Radix

## Getting started

The basic requirements are covered in [Getting started](guides/getting-started/).

## Configuring an app

The most beginner-friendly way to get started is the [Configuring an app](guides/configure-an-app/) guide. You can also watch the [Introduction to Radix video](https://statoilsrm.sharepoint.com/portals/hub/_layouts/15/PointPublishing.aspx?app=video&p=p&chid=653b6223-6ef5-4e5b-8388-ca8c77da4c7a&vid=3a64412f-0227-489d-9fda-f5f9845aacae) 🎥 for a more visual overview.

Builds in Radix are Docker builds! The [Docker builds](guides/docker/) guide has recommendations for creating good `Dockerfile`s that work well in the cloud ☁️

## Configure external alias

Radix will generate automatic domains with SSL certificates for your application, but you can also have [your own custom domains](guides/external-alias), as long as you bring your own certificate.

# Building, deploying and managing the app

How should you set up Git branches and Radix environments?

## Workflows

Read about [workflows](guides/workflows/) for an overview. 

## Promotion

A common strategy is to use [promotion](guides/deployment-promotion) to control how deployments end up in environments.

## Application start, stop, restart function

Another functionality available is the ability to [restart, stop and start a component](guides/component-start-stop-restart/), the feature is available on your app component page in the Web Console

## Deploy only - other CI tool

Teams that have a need for more advanced CI feature can use other CI tools and [deploy into Radix](guides/deploy-only). This feature is in progress, utilised by only a few teams. If you have any input or would like to be involved in testing this feature, please contact us for a walkthrough. 

## Resource allocation - cost

To ensure that an application is allocated enough resources to run as it should, it is important to set resource requirements for containers. This resource allocation is also used to distribute cost to an application. An app without resource requirements specified will be allocated default [values](https://github.com/equinor/radix-operator/blob/master/charts/radix-operator/values.yaml#L24). A guide on how to find resource requests and limits for an app can be found [here](guides/resource-request)

# Authentication

There is no checkbox that automatically provide authentication for your application in Radix. However there is still several way to introduce it to new and existing applications, without to much work. The [Authentication](guides/authentication/) guide goes through the basic to get authentication going for a Client and API. 

# Monitoring

You can use monitoring "out of the box" (the link to Grafana is in the top-right corner of the [Web Console](https://console.radix.equinor.com)). But you will get the most value by implementing [monitoring relevant for your app](guides/monitoring).

# Samples and scenarios

We also have a collection of [scenarios](guides/scenarios/) that can be used as templates for new or existing projects.
