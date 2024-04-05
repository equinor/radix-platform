# Digicert cluster issuer

Scripts for managing secrets required by Flux to install Digicert cluster issuers.

## Bootstrap
Replaced by external secret operator  
~~Run script [`./bootstrap.sh`](./bootstrap.sh), see script header for more how.~~

~~Bootstrap will~~
~~1. Read Digicert external account info from keyvault.~~
~~1. Create a Kubernetes secret with this info used by Flux to install ACME cluster issuers for Digicert~~

## Update external account values

Run script [`./update_account.sh`](./update_account.sh), see script header for more how.  
The script will update the Key Vault secret that holds Digicert account info. You should run [`./bootstrap.sh`](./bootstrap.sh) afterwards to update the Kubernetes secret used by Flux.

Required input values must be obtained from Equinor's account manager for Digicert.
