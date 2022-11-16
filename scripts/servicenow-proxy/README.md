# Refresh Radix ServiceNow Proxy Secrets


## Refresh client secret for app registration ar_radix_servicenow_proxy_client

App registration `ar_radix_servicenow_proxy_client` is used by the `radix-servicenow-proxy` application to request an access token valid for bearer authorization with the ServiceNow API.

Each cluster zone+environment has its own secret for this app registration.

1. Refresh app registration secret and store it in keyvault for a specific zone+environment with script [`refresh_app_registration_credentials.sh`](./refresh_app_registration_credentials.sh).
1. Update the `PROXY_SERVICENOW_CLIENT_SECRET` secret for Radix application `radix-servicenow-proxy` with script [`update_secret_for_radix_servicenow_proxy.sh`](./../update_secret_for_radix_servicenow_proxy.sh). The script updates the secret in qa and prod environments and restarts the deployment.

## Refresh API key (APIM subscription key)

The API key is a common key for the `radix-servicenow-proxy` application in all Radix clusters. When a new key is required, all clusters must be updated.

To request a new API key, read section `How to configure resources like OAuth connectors, backends, products or subscriptions in omniaapimtest and omniaapim?` in [Omnia documentation](https://docs.omnia.equinor.com/services/omniaapim/faq/).

1. Store the new key in all keyvaults by running [refresh_api_key](./refresh_api_key.sh) for each Radix zone.
1. Update the `PROXY_SERVICENOW_API_KEY` secret for Radix application `radix-servicenow-proxy` with script [`update_secret_for_radix_servicenow_proxy.sh`](./../update_secret_for_radix_servicenow_proxy.sh). The script updates the secret in qa and prod environments and restarts the deployment.



