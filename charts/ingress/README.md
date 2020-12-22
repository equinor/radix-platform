# Ingress

## Purpose

To create a custom ingress that point to an existing application running in the cluster.  

_Scenario:_  
App "myApp" has by default the url http://myapp-prod.cluster11.radix.equinor.com.  
I want a more user friendly url like "console.radix.equinor.com" to point to the same app.  

To enable this functionality I first need to create a dns alias in the dns zone that point to the cluster which host the app.  
Then I will create a custom ingress that redirects traffic from the alias to the app. This componet will help you create that custom ingress.

## Developing

```
cd radix-platform/charts/ingress
az acr helm repo add --name radixprod && helm repo update
rm requirements.lock
helm dep up
cd ..
tar -zcvf ingress-1.0.3.tgz ingress
az acr helm push --name radixprod ingress-1.0.3.tgz
```

## Installing

### Preparations

1. Make sure you have write access to the dns zone (ex "radix.equinor.com")
2. Make sure you have platform developer access to the cluster

### 1. Configure environment variabels

```
# Set alias script vars
RADIX_ZONE_NAME="radix.equinor.com"                                         # The name of the dns zone
RADIX_APP_CNAME="web-radix-web-console-prod.cluster11.radix.equinor.com"    # The CNAME you want to create an alias for
RADIX_APP_ALIAS_NAME="console"                                              # The name of the alias
RADIX_APP_NAME="radix-web-console"                                          # The name of the app in the cluster
RADIX_APP_ENVIRONMENT="prod"                                                # The app environment in the cluster (ex: "prod", "qa", "test")
RADIX_APP_COMPONENT="web"                                                   # The component which should receive the traffic
RADIX_APP_COMPONENT_PORT="8080"
RADIX_HELM_REPO="radixprod"                                                 # The name of the helm repo which host the ingress chart. In ACR this is the name of the acr instance.
```


### 2. Create the alias in the dns zone

```
# Create alias in the dns zone
az network dns record-set cname set-record \
    --resource-group common \
    --zone-name "$RADIX_ZONE_NAME" \
    --record-set-name "$RADIX_APP_ALIAS_NAME" \
    --cname "$RADIX_APP_CNAME"
```

### 3. Run the helm chart to create the custom ingress

```
helm upgrade --install radix-ingress-"$RADIX_APP_ALIAS_NAME" "$RADIX_HELM_REPO"/ingress \
    --version 1.0.3 \
    --set aliasUrl="$RADIX_APP_ALIAS_NAME.$RADIX_ZONE_NAME" \
    --set application="$RADIX_APP_NAME" \
    --set namespace="$RADIX_APP_NAMESPACE" \
    --set component="$RADIX_APP_COMPONENT" \
    --set componentPort="$RADIX_APP_COMPONENT_PORT" \
    --set enableAutoTLS=true

```

Done!