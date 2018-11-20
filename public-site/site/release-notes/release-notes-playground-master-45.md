---
title: Release Notes - playground-master-45
layout: document
toc: true
---

Release: `playground-master-45`  
Version: `a8794f70b2047a5d50d087f0a401ed73fa4ecf10`  
Channel: weekly

Release for week 45 in weekly [channel]({% link releases.md %}).

## Shortcuts
* [Web console](https://web-radix-web-console-prod.playground-master-45.dev.radix.equinor.com)


## New
* -

## Improvements
* -

## Fixes
- Operator is not seeing the latest rd and is unable to recover from azure bug:
  - If CRDs temporarily gets dropped from ETCD, the operator will recover when they re-appear
- Fix swagger issue on pipeline jobs
  - Fixed problems with contract testing in the web console

## Known issues
* Missing tls certs for dns alias for web-console and radix-platform

## Ops
* Kubernetes version 1.11.3
  
