---
title: Post-mortem for cluster "weekly-51" in DEV environment 2019-01-19
layout: document
toc: true
---

# Post Mortem - Bad Helm Deploy

## Timeline

### 2019-01-19 Saturday:

Stian: As part of making a helm chart for external monitoring I copied a `helm upgrade --install` command from radix-platform but forgot to change the release name. Should not have been a problem, but the `az aks` cluster creation command did not actually change the `kubectl` context as I assumed. The result was that my new chart overwrote the `radix-stage1` chart in the `weekly-51` cluster.

This in itself should not be a problem since `helm` in theory is idempotent and we can re-apply the correct `radix-stage1` chart and everything is back up in minutes. But the `install_base_components` script that Inge and Dafferianto had been working on recently was either not finished or working or documented enough so I was unable to re-install the correct `radix-stage1` chart on the cluster again.

I then had no other choice but to post on Slack that the platform was down and I was unable to fix it without assistance.

At this point the cluster did not work as expected since some resources and CRDs had been deleted by helm.

### 2019-01-21 Monday:

Radix Team:

1. We inform the platform users on the slack support channel that the cluster hosting their apps is down
1. We verify that the cluster is indeed corrupted due to a bad deploy of radix-stage-1 base components package (helm chart)
1. The decision is made to abandon the cluster as the team has a current sprint task to migrate users to a new beta cluster in the PROD environment anyway in order to refactor the entire DEV infrastructure environment.
1. We change the radix platform aliases to point to cluster "beta-3.radix.equinor.com" in PROD environment
1. We inform the users about how to migrate their apps to the "beta-3" cluster on slack support channel and by direct contact
1. We start on the "refactor DEV infrastructure" story  

### 2019-01-25 Friday:

1. Refactoring of the DEV infrastructure environment is completed
1. Users have migrated to "beta-3.radix.equinor.com" in PROD environment during the week
1. We announce the "weekly-4" cluster in the DEV environment on the slack internal team channel, as this cluster exist for internal development purposes

Users are back in business.

## Root causes

  * Operator mistake messed up an important helm deployment on the wrong cluster.
  * The normal helm restore procedure not working as expected.
  * Not enough experience on the team to heal a broken helm deployment.
  * Not having an alternative cluster to migrate users to quickly.

## Impact

The weekly cluster was unavailable for 4-5 days until a new prod environment was ready.

Disruptions on the weekly dev cluster should not have much impact but some users were still using it awaiting a more stable production environment.

## Mitigations

  * Implemented: Alternative cluster ready.
  * Implemented: Helm install/restore working idempotently.
  * Suggested: Make it harder to accidentally execute for example helm commands in the wrong Kubernetes context.
  * Suggested: Increase helm knowledge in the team.

