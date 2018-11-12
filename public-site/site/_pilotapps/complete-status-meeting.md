---
title: Web conference with Complete on 2018-08-06
layout: document
parent: ['Documentation', '../documentation.html']
toc: true
---

_Summary of web conference with Kjell Wilhelm Kongsvik in Complete team on 2018-08-06_

Complete team is back from vacation and getting ready to deploy their backend application to Omnia Radix.

The frontend is a "native" Electron application that the end-user themselves download from GitHub. This is because the frontend needs access to the local filesystem on the client. Therefore only the backend will be deployed on Omnia Radix.

**Preparations on the way user-side**:
  - Move PostgreSQL database from a local disk-backed container to Azure SQL.
  - Add authenticaton to backend so it can be exposed on the internet.
  - Re-write tests in Dockerfile so application can be tested and built in Brigade running on Omnia Radix.

**Needs**:
  - Define environment variables in radixconfig.yaml for DB hostname and user.
  - Define secret variables in portal or kubectl for DB password.

**Wants**:
  - GitHub integration where a pull request triggers a test build and posts results on the pull request in GitHub.
  - Quicker tests and builds than Travis does currently. Backend now takes 2.5 minutes and frontend 4.5 minutes. Getting down to 30 seconds would be great. See comments below.

**Questions**:
  - Is it possible to restrict access to the applications based on client IP? No.
  - PostgreSQL has IP filter. Which IPs are the client connecting from? Unknown since it's all dynamic. See comments below.

## Comments

### Quicker builds

Two ways of speeding up builds is caching Docker image layers and having a local HTTP caching proxy for external dependencies. We need to investigate how Brigade interfaces with Docker daemons for building and see what possibilities there are for caching. We could also set up a test with a HTTP caching proxy. Network bandwidth to/from Azure is usually pretty fast so not sure how big the effect would be. Maybe there could be gains on for example NodeJS projects which have thousands of dependencies by reducing round-trip-latency with a local HTTP cache.

If Docker image caching could leak information to other builds/teams it could still make sense to have it as an optional feature for applications which does not contain anything sensitive.

Comment from Nelson 2018-08-06: Recent Docker versions have a `cache-from` option where Docker can re-use lower layers of another previously built image if they are the same. (See https://medium.com/@gajus/making-docker-in-docker-builds-x2-faster-using-docker-cache-from-option-c01febd8ef84)

### Restricting PostgreSQL access

We are going to investigate if it's possible to narrow down access between Omnia Radix Cluster and Azure SQL on the network level, without using IP-filters (will not work since everything is dynamic). This needs to work across subscriptions and resource groups since Omnia Radix team owns the Kubernetes clusters and the Complete team owns their PostgreSQL database.

Comment from Nelson 2018-08-06: PostgreSQL also supports mutual certificate authentication: https://www.postgresql.org/docs/9.6/static/ssl-tcp.html - If that could add some of the extra security previously offered by restricting network access.
