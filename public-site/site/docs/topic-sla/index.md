---
title: SLA
layout: document
parent: ["Docs", "../../docs.html"]
toc: true
---


# Service level agreement

We are experimenting with an approach with "release channels" which differ in update frequency, service level agreement(SLA) and expected stability. See [link](/public-site/site/guides/getting-started/index.md#the-radix-clusters) for more information on clusters

|    Cluster            |             Purpose                              |      Termination/Upgrade    |   Support    |     
|-----------------------|--------------------------------------------------|:---------------------------:|:------------:|
| **Production**        | Radix production - currenly limited access       | Every ~6 months             | Yes          |   
| **Playground**        | "Open" for test and experimenting with Radix     |                             | Best-effort  |  

## SLA - Production 

Should be used when your team has chosen radix as PaaS for a product under development or in production. 

### Support

Schedule for Radix DevOps/Support team - 08:00 - 16:00 CET/CEST on Norwegian working days
  * **Support channels:** File issue on [radix-platform repo](https://github.com/equinor/radix-platform/issues) or ask on #omnia_radix_support on Slack.  
  * **Response time:** As soon as possible within business hours, at least next business day. 
  * **On call duty:** No.
  * **Resolution time:** Cannot be guaranteed, but for critical issues work on fixing the problem will start immediately and continue within business hours until resolved.


### Uptime

  * **Platform monthly uptime: 99.5%** - expected uptime for radix as a hosting platform. 
  * **Omnia Radix services monthly uptime: 98%** - expected uptime for radix services, as CI/CD and monitoring. 
  * **Planned maintenance:** We will announce planned maintenance at least 2 business days in advance. Downtime during planned maintenance does not count towards uptime goals.
  
### Associated operational risks
- No incident management beyond schedule "Norway - default" - i.e. no support after 16:00 CET/CEST on Norwegian working days.
- Risks for infrastructure downtime despite robust, high availability infrastructure.
- Disaster recovery in experimentation for platform and possibly apps.


## SLA - Playground

Use Playground for testing Radix, see if it’s a good fit for your projects, and provide feedback to us. When you are ready to commit, you can register your application in the Production cluster, which has improved stability.

**Support:** same channel as for Production cluster. Help will be provided when team has the time. 

**Uptime:** "Best-effort", but no guarantee uptime. Planned maintenance is announced as early as possible. 

**In Playground cluster - hosted applications might be lost during maintenance, upgrades or migrations.**

