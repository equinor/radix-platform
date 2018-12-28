{{- define "azuredns-secret" }}
{{- printf "%s" .Values.azureDNS.password | b64enc }}
{{- end }}

{{- define "external-dns-secret" }}
{{- printf "{\"tenantId\": \"%s\", \"subscriptionId\": \"%s\", \"aadClientId\": \"%s\", \"aadClientSecret\": \"%s\", \"resourceGroup\": \"common\"}" .Values.azureDNS.tenantID .Values.azureDNS.subscriptionID .Values.azureDNS.clientId .Values.azureDNS.password | b64enc }}
{{- end }}

{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.imageCredentials.registry (printf "%s:%s" .Values.imageCredentials.username .Values.imageCredentials.password | b64enc) | b64enc }}
{{- end }}
