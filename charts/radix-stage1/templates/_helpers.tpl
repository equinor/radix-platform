{{- define "azuredns-secret" }}
{{- printf "%s" .Values.azureDnsSecret | b64enc }}
{{- end }}

 {{- define "external-dns-secret" }}
 {{- printf "%s" .Values.externalDnsAzureConfig | b64enc }}
 {{- end }}

{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.imageCredentials.registry (printf "%s:%s" .Values.imageCredentials.username .Values.imageCredentials.password | b64enc) | b64enc }}
{{- end }}
