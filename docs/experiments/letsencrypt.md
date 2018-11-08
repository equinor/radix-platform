Træfik supports using [Let's Encrypt](https://letsencrypt.org) for issuing TLS-certificates on-demand.

Whenever a new Ingress object with the annotation <code>kubernetes.io/tls-acme: "true"</code> is detected, Træfik will request a TLS-certificate from Let's Encrypt.

In order for this to work, the hostname referenced in the Ingress object needs to point to the Træfik instance issuing the request. 
This is because Let's Encrypt validates that you own the domain by doing a callback to Træfik by using the hostname you want a certificate for. 

[Sample config for Træfik](https://github.com/Statoil/staas-k8s/blob/master/loadbalancing/traefik-conf.yaml)

Read the official documents [here](https://docs.traefik.io/configuration/acme/)
