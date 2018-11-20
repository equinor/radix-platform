# Release Notes - playground-master-47
Release: `playground-master-47`  
Version:   
Channel: weekly

Release for week 47 in [weekly channel](../docs/releases.md#channels).

## Shortcuts
* [Web console](https://web-radix-web-console-prod.playground-master-47.dev.radix.equinor.com)


## New
- [OR-115] - Function: Validate RadixRegistration, RadixApplication and RadixDeploy
- [OR-188] - Web Console should automatically connect to same cluster where it runs
- [OR-263] - Functional: Show deployments
- [OR-273] - Functional: Show job details
- [OR-276] - Functional: Show aggregated logs (grouped per step)
- [OR-279] - Functional: Stream job details

## Improvements
- Refactor and simplify cluster creation with new helm charts and updated manual deploy steps
- [OR-240] - Refactor Swagger contracts on the API server based on the new structure suggested
- [OR-256] - Use draft for API server + build on platform

## Fixes
- TLS certs for DNS alias for web-console and radix-platform (documentation pages)
- [OR-184] - Is keploy key doesn't properly delete job after completion
- [OR-257] - Upgrade kaniko version to avoid bug + add caching to Kaniko
- [OR-281] - Swagger proptypes crashes on undefined references
- [OR-285] - Application secret disappears for each commit and push
- [OR-286] - Remove streamwatcher workaround in radix-operator

## Known issues
