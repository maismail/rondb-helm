{{/*
- Run all custom SQL init files
*/}}
{{- define "rondb.sqlInitContent" -}}
{{- range $k, $v := .Values.mysql.sqlInitContent }}
{{ $v | indent 4 }}
{{- end }}
{{- end -}}

{{- define "rondb.mysql.usersSecretName" -}}
{{- if and .Values.global .Values.global._hopsworks -}}
{{ include "hopsworkslib.mysql.usersSecretName" . }}
{{- else -}}
{{ .Values.mysql.credentialsSecretName }}
{{- end -}}
{{- end -}}
