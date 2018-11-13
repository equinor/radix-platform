---
title: Windows containers
layout: document
toc: true
---

## Azure AKS Support

As of 2018-04-13 Azure AKS does not support more than 1 node pool (https://github.com/Azure/AKS/issues/287). That means a cluster cannot contain Linux + Windows Kubernetes nodes (and also cannot be vertically scaled after creation).

According to the GH issue it is on the roadmap for Q3-Q4 2018.

## .NET Core apps

.NET Core applications can be built and run on Linux: https://docs.microsoft.com/en-us/dotnet/core/linux-prerequisites?tabs=netcore2x