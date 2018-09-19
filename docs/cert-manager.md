# cert-manager

We use [cert-manager](https://github.com/jetstack/cert-manager) to provide automatic SSL/TLS certificate generation in the cluster using Let's Encrypt.

First we will go through the manual installation of cert-manager and then go through how it all connects.

## Prerequisities

Since we will use DNS challenges for verifying ownership of our domains we need a Azure DNS zone and a Service Prinical (user) that has permissions to edit DNS records.

We assume an existing DNS zone named `dev.radix.equinor.com` in the resource group `radix-common-dev`

Start by getting the subscription ID of the Omnia Radix Development subscription:

    az account list --output table

Then create a new Service Principal filling in the subscription ID from before:

    az ad sp create-for-rbac --name AKSCertManager --role="DNS Zone Contributor" --scopes="/subscriptions/<subscriptionId>/resourceGroups/radix-common-dev"

Keep the response handy for using in later steps.

## cert-manager

Install cert-manager from the official Helm chart:

    helm upgrade --install stable/cert-manager cert-manager --set ingressShim.defaultIssuerName=letsencrypt-prod --set ingressShim.defaultIssuerKind=ClusterIssuer --set ingressShim.defaultACMEChallengeType=dns01 --set ingressShim.defaultACMEDNS01ChallengeProvider=azure-dns

Now create a ClusterIssuer:

    apiVersion: certmanager.k8s.io/v1alpha1
    kind: ClusterIssuer
    metadata:
    name: letsencrypt-prod
    spec:
    acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: sov@equinor.com
        privateKeySecretRef:
            name: letsencrypt-prod
        dns01:
        providers:
        - name: azure-dns
            azuredns:
            clientID: ba5ac354-1a07-4c8a-945d-a9846cfcda9c # appID from az ad sp create-for-rbac
            clientSecretSecretRef:
                key: client-secret
                name: azuredns-config
            hostedZoneName: dev.radix.equinor.com
            resourceGroupName: radix-common-dev
            subscriptionID: 16ede44b-1f74-40a5-b428-46cca9a5741b # subscriptionID from az account list --output table
            tenantID: 3aa4a235-b6e2-48d5-9195-7fcf05b459b0 # tenantID from az ad sp create-for-rbac
            
And the secret containing the password for the Service Principal:

    apiVersion: v1
    kind: Secret
    type: Opaque
    metadata:
        name: "azuredns-config"
    data:
        client-secret: <base 64 encoded password from az ad sp create-for-rbac>

Now create a Certificate object manually:

    apiVersion: certmanager.k8s.io/v1alpha1
    kind: Certificate
    metadata:
        name: "myservice-cert"
        namespace: default
    spec:
        secretName: "grafana-tls-secret"
        issuerRef:
            name: letsencrypt-prod
            kind: ClusterIssuer
        commonName: "myservice.dev.radix.equinor.com"
        dnsNames:
        - "myservice.dev.radix.equinor.com"
        acme:
            config:
            - dns01:
                provider: azure-dns
            domains:
            - "myservice.dev.radix.equinor.com"

This will create a "Certificate" named `myservice-cert`. It will look for the ClusterIssuer `letsencrypt-prod` that we created before. It will use the domain names in commonName, dnsNames and domains somehow, not sure how they differ though. It will use the provider `azure-dns` that is configured in the provider list in the ClusterIssuer for verifying ownership. When a certificate is successfully retrieved, the private key will be stored in the secret `myservice-tls-secret`.

But we do not want to be creating these Certificate objects all the time. `cert-manager` comes with a nginx-ingress shim that will look at Ingress objects for extra annotations that can be used to auto-create Certificate objects. For these to work we need to set the default issuers and challenge values:

    defaultIssuerName=letsencrypt-prod
    defaultIssuerKind=ClusterIssuer
    defaultACMEChallengeType=dns01
    defaultACMEDNS01ChallengeProvider=azure-dns

We already set these when doing helm install so they should be ready.

To have ingress-shim auto-create certificates we just add this annotation to an `Ingress` object:

    metadata:
        annotations:
            kubernetes.io/tls-acme: "true"

The full ingress would look something like this:

    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
        annotations:
            kubernetes.io/tls-acme: "true"
        labels:
            app: grafana
            chart: grafana-1.14.6
            heritage: Tiller
            release: grafana
        name: grafana
        namespace: default
    spec:
        rules:
        - host: grafana.playground-cert-manager-sg.dev.radix.equinor.com
            http:
            paths:
            - backend:
                serviceName: grafana
                servicePort: 80
                path: /
        tls:
        - hosts:
            - grafana.playground-cert-manager-sg.dev.radix.equinor.com
            secretName: grafana-tls-secret

Note most Helm charts allow you to set Ingress hosts and annotations in their values.yaml files.

## How it all (should) work

Some resource creates an Ingress object refering to an at the moment non-existing secret/tls-certificate. Ingress-shim which is running in the cert-manager container will look for the correct annotations. It finds that this Ingress has that annotation and it creates a Certificate object based on data from the Ingress and the defaultIssuer* and defaultACME* settings.

Seeing a new Certificate, cert-manager will look at the provider and issuer references and try to find a matching ClusterIssuer. If it finds it it will use the settings from the ClusterIssuer to perform the certificate request process and hopefully retrieve a new signed certificate and put that into `grafana-tls-secret`.

The DNS challenge verification process might take a minute or two to complete due to DNS propagation and caching.

PS: Until this process is complete and `grafana-tls-secret` is populated nginx-ingress will not serve this service but a default 404 backend.
