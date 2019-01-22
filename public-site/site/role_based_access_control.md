---
title: Role Based Access Control
layout: document
toc: true
---

Each application will be limited to the members of the AD group provided on the application registration <sup><sup>1</sup></sup>. This will grant access to manage the application on the Radix platform, e.g deleting the applaction from the platform, view jobs and logs. If no AD group is provided during the registration, the application will be available to all Radix users (app developers).

We point out that this is not to control the access within the app itself.

<sup><sup>1</sup></sup> Currently all application will be listed to all users, this is a known problem and will be fixed once we reach production. However, only applications a user has access to can be viewed in a detail view