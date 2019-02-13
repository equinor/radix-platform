---
title: Security
layout: document
parent: ['Docs', '../../docs.html']
toc: true
---

# Role Based Access Control

Membership in the 'Radix Platform User' AD group grants access to

- Radix Web Console
- Grafana Dashboard (Monitoring)

Access to manage each application is limited to the members of the AD group provided during application registration. Management of applications can be e.g. deleting the application from the Radix Platform, view jobs and logs.

> Currently all applications are listed (but not accessible) to all Radix users. This is a known problem and will be fixed. Only applications a user has access to can be viewed in detail and managed.

If no AD group is provided during the registration the application will be available to all Radix users (members of the 'Radix Platform Users' AD group).

# Authentication

It is important to understand that **application authentication is not handled by Radix**. The application endpoints will be public. Each team managing an application hosted on Radix is responsible for authenticating their users.

For an example of in-app authentication using AD have a look at [Radix Authentication Example](https://github.com/equinor/radix-example-auth).
