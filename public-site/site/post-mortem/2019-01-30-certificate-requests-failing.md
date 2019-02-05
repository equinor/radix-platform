---
title: Post-mortem for cluster "beta-3" in PROD environment 2018-12-04
layout: document
toc: true
---

# Post Mortem - Certificate Requests Failing

Request for TLS certificates fails in all clusters

## Timeline

### Wednesday 2019-01-30 - 08:35

While troubleshooting another active incident [2019-01-30-kubernetes-objects-missing](2019-01-30-kubernetes-objects-missing.md) we discover that automatic certificate requests from `cert-manager` to `lets-encrypt` are failing.

### 09:30

We start by investigating the logs of `cert-manager` where we initially lock on to the words "Rate Limit" and since we have had a fear of running into Certificate Request Rate Limits (CR Rate Limit) we start down the path of figuring out how we can reduce the number of Certificate Requests. However, when reasoning a bit more it seems unlikely we should hit the CR Rate Limit at this point. When reviewing the logs again it actually says Authorization Failure Rate Limit which indicates something is wrong with authentication instead. 

When trying to figure out why Cert Requests fail I do a combination of:
  * Running and inspecting in cert-manager
  * Running certbot locally to get certificates
  * Investigating DNS records as seen from our cluster, inside Equinor network and outside on OneCall 4G.

The root cause seems to be:

`Failed authorization procedure. beta-4.radix.equinor.com (dns-01): urn:ietf:params:acme:error:dns :: DNS problem: SERVFAIL looking up CAA for beta-4.radix.equinor.com`

SERVFAIL should not happen under any circumstance and this prevents lets-encrypt from issuing us our certificates.

> CAA records limits which Certificate Authorities (CA) are allowed to issue certificate for a given domain. CAA can be set on any sub-level (such as dev.radix.equinor.com, radix.equinor.com, equinor.com) and the most specific overrides parent records. Domains do not have to have CAA records, which means any CA can issue certificates. Equinor.com has `digicert` is their only allowed CA. We have added `godaddy` and `letsencrypt` via CAA to `radix.equinor.com`. There is no CAA for our sub-domains, which means for `beta-4.radix.equinor.com` the CAA for `radix.equinor.com` will be in effect. However, lets-encrypt still needs to check if there exists a CAA record for `beta-4.radix.equinor.com` before checking and using the parent `radix.equinor.com` CAA. This first query is what appeared to fail.

### 10:20

Stian file support ticket LetsEncrypt challenges fail because of SERVFAIL (119013024000662) with Azure since Lets Encrypt does not have any official support channels.

### 10:30

While waiting for response from Azure I review the rate limits at https://letsencrypt.org/docs/rate-limits/ and search for a tool that allows me to show the team the CR Rate Limit is not the probable cause.

Stian use `lectl` to get a report of our lets-encrypt certificates:

    wget https://raw.githubusercontent.com/sahsanu/lectl/master/lectl
    bash lectl -m radix.equinor.com

It reported that we can issue 17 more certificates at the day of the incident. So the problem is not CR Rate Limit.

> CR Rate Limit is 50 in a 7 day moving window. At Monday 2019-02-04 we have issued 13 of 50 in the last 7 days.

### 11:43

A senior engineer from Azure call Stian and he logs on to view Stian's desktop while Stian demonstrate the problem. He is not aware of any problems on Azure and cannot find any problems when reviewing logs on their backend. As a suggestion he asks Stian to create CAA record for `beta-4.radix.equinor.com` which works.

Stian is not happy since this is inconsistent with how things are supposed to work and is probably a race condition or other kind of fluke, but the engineer is happy and closes the ticket anyway.

### 13:30

With Azure saying they are not experiencing problems and adding CAA `beta-4.radix.equinor.com` works Stian turn to LetsEncrypt community forums for any hints. There does not seem to be any reports of similar problems so Stian create a thread ( https://community.letsencrypt.org/t/caa-behaviour-changed/84706/2 ) explaining the problem as good as possible. The replies the first day is that this is indeed a DNS issue.

We stop working on this as it's now working for `beta-4.radix.equinor.com` and that it's in Stian's opinion most likely an external issue we cannot fix.

### Thursday

More people on the lets-encrypt community forum thread are reporting the same problem with Azure DNS and lets-encrypt.

### Friday

Reports about DNS problems at a Microsoft third party supplier, Level 3: https://nakedsecurity.sophos.com/2019/02/01/dns-outage-turns-tables-on-azure-database-users/

### Saturday

Someone reports it as an issue on AKS GitHub: https://github.com/Azure/AKS/issues/806

### Monday

Inge reports that he cannot get certificates on a new cluster. Stian checks and it's the same SERVFAIL problem. Stian re-open ticket 119013024000662 and try to escalate via Mohammad on #omnia_radix_aks on Slack.

## Root causes

DNS problems at Level 3 caused a partial outage on Azure DNS that caused lets-encrypt DNS challenge to fail.

## Impact

We could not create new clusters with valid TLS certificates.

## Mitigations

There are very few things we can do if DNS is not working properly, other than changing provider from Azure DNS to someone else in the hope that they are more stable.

  * Suggested: Monitor logs better so that we can catch errors like this before they pop up somewhere else in the infrastructure.
  * Suggested: Not related to this incident, but monitoring issued certificates to monitor if we are at risk of hitting CR Rate Limit might be helpful.
