# Radix app aliases

Users should have an easy url to radix apps in each radix zone.  
We can configure this by creating 
- a custom ingress for each radix app in the active cluster
- a CNAME in the radix zone dns that point to the custom ingress

## Components

- `bootstrap.sh`  
   Shell script for creating alias configuration.  
   It will process all the app alias configs found in the `.\config\` dir.
- `.\configs\*.env`  
   App alias configs in the form of shell script `.env` files

## How to add an app alias

1. Add another app alias config in dir `.\config\`
2. Run script (see top of script for how to use)