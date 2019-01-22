---
title: Role Based Access Control
layout: document
toc: true
---
Membership in the 'Radix Platform User' AD group grants access to
 - Radix Platform Web Console
 - Grafana Dashboard (Monitoring)


Access to manage each application are limited to the members of the AD group provided on the application registration <sup><sup>1</sup></sup>. Management of applications can be e.g. deleting the application from the Radix Platform, view jobs and logs. 

If no AD group is provided during the registration, the application will be available to all Radix users (members of the 'Radix Platform Users' AD group).

We point out that this is **not** to control the access within the application itself.

<sup><sup>1</sup></sup> Currently all application are listed, this is a known problem and will be fixed. However, only applications a user has access to can be viewed in a detail view.