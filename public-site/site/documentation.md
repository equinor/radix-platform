---
title: Documentation
layout: document
toc: true
---

> This page is still lacking most content. If you have questions, come [speak with us]({% link community.md %})

# Radix platform

## Concepts

- Application
- Component
- Environment
- Pipeline
- Job
- Deployment

## Systems

- Web console
- CLI
- Metrics (Prometheus)
- Monitoring (Grafana)
- Radix API
- Operator

# Using Radix

## Workflows

How to define your workflow in Radix; examples for `radixconfig.yaml`

- [Overview of workflows]({% link workflows.md %})
- Git flow
- Trunk-based development (promotion)

## `Dockerfile` examples and best practice

{% for dockerfile in site.dockerfiles %}

- [{{ dockerfile.title }}]({{ dockerfile.url }})

{% endfor %}

## Monitoring

TODO
