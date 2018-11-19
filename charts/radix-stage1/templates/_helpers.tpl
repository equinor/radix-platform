{{- define "azuredns-secret" }}
{{- printf "%s" .Values.certManagerAzureDnsSecret | b64enc }}
{{- end }}