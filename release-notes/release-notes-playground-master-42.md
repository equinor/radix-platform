# Release Notes
Release: `playground-master-42`  
Version: `8eea3123e45643c6348492519f265451fd369a56`

The Omnia Radix team is even prouder than last week to do our second release to our [weekly channel](../docs/releases.md#channels).

## Shortcuts
* [Web console](https://web-radix-web-console-prod.playground-master-42.dev.radix.equinor.com)


## New
* We are moving into [trunk based development](https://trunkbaseddevelopment.com/) territory.  
  This cluster was build using latest commit in repo radix-boot-configs/master.  
  `version` = commit hash in master branch.

## Improvements
* "Radix builds radix" - all "app like" base components are installed using radix CICD pipeline
* All base components use shared wildcard tls cert

## Fixes
* Release notes are now back to the future ("42" made a cameo appearance in previous week note)

## Known issues
* The canary is spawn camped / stuck in RR.  

## Ops
* Kubernetes version 1.11.2
  
