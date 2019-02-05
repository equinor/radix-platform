---
title: Post-mortem for cluster "beta-3" in PROD environment 2018-12-04
layout: document
toc: true
---

# Post Mortem - Kubernetes Objects Missing

## Timeline

### Wednesday 2019-01-30 - 08:35

1. A user ask if we have introduced unannounced downtime for PROD cluster in slack support channel
1. We investigate and discover that apps and k8s objects are missing in "beta-3" cluster in the PROD environment
1. Same discovery is made in multiple clusters in DEV environment
1. We inform users that current PROD cluster (beta-3) is down and that we are working resolving the problem

### 09:10

Kjell-Erik opens support ticket 119013025000486 with Azure (priority A). Azure called (twice) requesting information around business impact, where we agreed to lower the case to priority B. 

### 09:20

1. The team conclude that the most likely cause is a corrupted etcd as the components went missing overnight with no new deployment made by either the team or any users
1. We discover that all radix CRDs are intact
1. Based on similar issue we had in October, support ticket 118102225001498, we considered the cluster to be lost and made the decision to create a new cluster. We would manually migrate all user apps to the new cluster by transfering the radix CRDs from old to new cluster
1. We discover that working clusters no longer can request TLS certs. Same problem appear in new clusters. We start investigating this as a separate incident simultaneously, covered in [2019-01-30-certificate-requests-failing.md].

We make a plan where Jonas and Kjell-Erik:
 1. Find a cluster with working certificates
 1. Export the certificates
 1. Delete the cluster and recreate a new cluster with the same name
 1. Import the old certificates valid for the same domains
 1. Redirect DNS aliases to point to this cluster to make this cluster the active one.

Cluster `snart` in Prod subscription was considered most suited for this.

Meanwhile, Inge plans to migrate customer apps from `beta-3` cluster to the fresh `snart` cluster.

Procedure:

1. kubectl get rr > all_rr.yaml
2. kubectl get ra --all-namespaces > all_ra.yaml
3. Edit all_rr.yaml and all_ra.yaml to remove radix components + creationTimestamp, generation, resourceVersion, selfLink and uid from metadata
4. kubectl apply -f all_rr.yaml
5. kubectl apply -f all_ra.yaml

### 13:19

Both moving TLS certificates and migrating applications is successful:

- Cluster `snart` in PROD subscription is ready and has intact TLS certificates
- PROD aliases point to `snart`
- All apps successfully migrated to cluster `snart`

We still need users to manually update their webhook URLs in their respective GitHub repositories.

We inform the users on slack support channel:

```
*Issue has been fixed*

We have a new production cluster (named `snart`) operating now. You can access the web console via the usual URL: https://console.radix.equinor.com

*There are two actions required on your part*

1) The webhook set up in your app in GitHub must be updated. It probably was set to “https://webhook-radix-github-webhook-prod.beta-3.radix.equinor.com/events/github”. This must now change to “https://webhook.radix.equinor.com/events/github”. You can update it at this URL: `https://github.com/equinor/ <YOUR-APP-NAME> /settings/hooks`

2) All applications have been migrated to the new cluster, *but they have not been deployed* (to avoid triggering any unexpected behaviours on app startup). To deploy your application you can either push a change to GitHub, or use “New job” feature in the Web Console. The URL for this is `https://console.radix.equinor.com/applications/ <YOUR-APP_NAME> /jobs/new`

Please note that generated URLs for your apps’ components and environments will have changed to `<COMPONENT NAME>-<ENVIRONMENT NAME>-<APP NAME>.snart.radix.equinor.com` (note the `snart` bit).
```

## Root causes

Unknown. We are somewhat certain that this is not under our control and is caused by something in AKS. AKS Engineers are still investigating issue.

## Impact

Cluster is in an unknown state and cannot really be trusted. Production platform is unavailable for 4-5 hours.

## Mitigations

  * Suggested: Have an emergency procedure for restoring operations if a cluster has it's state disappear. This might include regular backups of key objects such as RRs and ways to re-start all pipelines to get applications back up.
