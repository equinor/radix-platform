# Digicert cluster issuer

Scripts for managing secrets required by Flux to install Digicert cluster issuers.

## Bootstrap
Replaced by external secret operator  and flux

## Update external account values

Run script [`./update_account.sh`](./update_account.sh), see script header for more how.  
The script will update the Key Vault secret that holds Digicert account info. External Secrets Operator will sync the new values within 5min

Required input values must be obtained from Equinor's account manager for Digicert.
