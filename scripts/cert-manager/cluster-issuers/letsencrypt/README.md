# Lets Encrypt cluster issuer

Scripts for managing secrets required by Flux to install Lets Encrypt cluster issuers.

## Bootstrap

Run script [`./bootstrap.sh`](./bootstrap.sh), see script header for more how.  

Bootstrap will
1. Create a Kubernetes secret with info required by Flux to install ACME cluster DNS01 issuer for Lets Encrypt

