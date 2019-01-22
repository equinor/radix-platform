---
title: Documentation
layout: document
toc: true
---

> This page is still lacking most content. If you have questions, come [speak with us]({% link community.md %})

# Using Radix

## Workflows

How to define your workflow in Radix; examples for `radixconfig.yaml`

- [Overview of workflows]({% link workflows.md %})
- Git flow
- Trunk-based development (promotion)

## `Dockerfile` examples and best practice

Also see [scenarios and examples]({% link scenarios.md %})

{% for dockerfile in site.dockerfiles %}

- [{{ dockerfile.title }}]({{ dockerfile.url }})

{% endfor %}

## Security
 - [Access Control]({% link role_based_access_control.md %})
 - [Authentication]({% link authentication.md %})

## Index

 - [Azure AD Authentication]({% link azure-ad.md %})
 - [Monitoring]({% link monitoring-for-users.md %})
 - [Releases]({% link releases.md %})
 - [Principles]({% link principles.md %})

# Radix platform

## Meta

 - [Version control]({% link version-control.md %})
 - [Useful resources]({% link resources.md %})
 - [Cluster SLAs, checklists and tests]({% link cluster-sla-checklists-tests.md %})

## Concepts

- Application
- Component
- Environment
- Pipeline
- Job
- Deployment
- [Scaling, limiting, and metering in K8s]({% link scaling.md %})
- [Security]({% link security.md %})



## Systems

- Web console
- CLI
- Metrics (Prometheus)
- Monitoring (Grafana)
- Radix API
- Operator
- [Azure resources]({% link azure-resources.md %})
- [DNS]({% link dns.md %})
- [cert-manager]({% link cert-manager.md %})
- [Certificate management]({% link cert-management.md %})
- [Monitoring for Radix]({% link monitoring-for-radix.md %})



## Experiments and spikes

- [API Gateway comparison]({% link spikes/api-gateways.md %})
- [Docker image registries]({% link spikes/image-registries.md %})
- [Kubernetes on Raspberry Pi]({% link spikes/k8s-on-rpi.md %})
- [Pipeline framework]({% link spikes/pipeline-framework.md %})
- [Terraform]({% link spikes/terraform.md %})
- [Windows containers]({% link spikes/windows-containers.md %})
- [Authentication of dependency requests during build]({% link spikes/build-dependency-authentication.md %})

## Pilot applications

{% for file in site.pilotapps %}

- [{{ file.title }}]({{ file.url }})

{% endfor %}

