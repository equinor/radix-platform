---
title: Post-mortem for cluster "weekly-48-c" 2018-12-04
layout: document
toc: true
---

## Initial problems

Unable to connect to radix-components:

- https://server-radix-api-qa.weekly-48-c.dev.radix.equinor.com/swaggerui
- https://webhook-radix-github-webhook-prod.weekly-48-c.dev.radix.equinor.com

nslookup looks good, curl does not get an ip.All pods, ingresses etc are running.


## Fix attempt 1: clean reinstall base components - failed

Attempt at forcing a dns update by redeploying base component.  
Sidenote: For some unknown reason the webhook started to answer.

_Steps_:  

1. `Helm delete --purge` all releases.
1. Manually clean up leftovers from bad charts like “cert-manager”
1. `Helm update --install` then fails due to problems with radix-operator. It turns out radix-boot-configuration points to a very old version of radix-operator. Internal team discussion about versions lead to a manual deploy of radix-operator.
1. All scripted base components are now deployed, starting on manual steps.

_Result_:

- webhook ok
- radix-api is still unavailable from the outside

Attempt 1 has failed.  

## Fix attempt 2: external-dns component

Discovered a misconfiguration in the deploy of external-dns component

```
externalDns:
  deploymentTargetName: xx
The result of this is that external-dns is deployed with a default value for “txt-owner-id”

 containers:
      - args:
        - --txt-owner-id=xx
```

”deploymentTargetName” is an old radix-boot variable name that has been replaced by “clusterName”.

_Code fixed_:  
Updated external-dns chart to use correct variable name in repo,
https://github.com/equinor/radix-platform/blob/master/charts/radix-stage1/values.yaml

_Update external-dns by updating deploy yaml in cluster_:  
Cannot update external-dns by using helm update as it will reintroduce all the work described in attempt 1.
Pulled down deploy config of external-dns, updated and kubectl apply

```
 containers:
      - args:
        - --txt-owner-id=weekly-48-c
```

Restarted external-dns controller.
Restarted nginx-controller.

_Result_:  

- Still unable to connect to radix-api

Attempt 2 has failed.

## Fix attempt 3: azure dns zone records

Now that the cluster is configured to set the correct txt-owner-id we can attempt to fix the records in the dns zone and not have that fix overwritten by a bad cluster configuration.

Have an idea about what A records, TXT records and CNAME records are.  
Find out that what azure dns show is very different from that idea.  
Get confused for a long time.  
Come the realization that network people some times talk about A-, TXT- and CNAME-records as if they are objects to confuse programmers. Come to the realization that azure dns output is a revenge on both.

_Fix_:  
Manually find and delete all TXT records that has “owner-id=xx” to release lock on “cluster-48-c” in azure dns zone.

_Result_:

- Logs in external-dns contoller now show that it is able to add registrations using the correct owner-id
- Able to connect to https://server-radix-api-qa.weekly-48-c.dev.radix.equinor.com/swaggerui

Attempt 3 is looking good!

Will now continue on with manual install of radix components.  


## Fix attempt 4: complete manual install of base components

_Challenge_:
Manual deploy steps are outdated as components have moved on to a new branching strategy.

Have a sit-down with Core SIG to figure out what the new steps are.
Update steps in radix-boot-config.

_Deploy radix-components using manual steps_:

- All components install and run ok
- Will not update dns alias as week 49 cluster is also on its way.

_Result_:  

Success!  
Cluster “weekly-48-c” is now up again.