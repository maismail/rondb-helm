# Also supports nothing defined at all (local registry)
{{- define "image_registry" -}}
{{- if and $.Values.global $.Values.global.imageRegistry -}}
{{- $.Values.global.imageRegistry -}}/hopsworks/
{{- else if $.Values.image.registry -}}
{{- $.Values.image.registry -}}/hopsworks/
{{- end -}}
{{- end -}}

{{/*
Create the main Hopsworks user
*/}}
{{- define "rondb.sqlInitContent" -}}
{{- if and .Values.global .Values.global.mysql.user .Values.global.mysql.password .Values.global.mysql.grant_on_host }}
{{ .Values.mysql.sqlInitContent }}

CREATE USER IF NOT EXISTS '{{ .Values.global.mysql.user }}'@'{{ .Values.global.mysql.grant_on_host }}' IDENTIFIED WITH mysql_native_password BY '{{ .Values.global.mysql.password }}';
GRANT ALL PRIVILEGES ON *.* TO '{{ .Values.global.mysql.user }}'@'{{ .Values.global.mysql.grant_on_host }}' WITH GRANT OPTION;
GRANT NDB_STORED_USER ON *.* TO '{{ .Values.global.mysql.user }}'@'{{ .Values.global.mysql.grant_on_host }}';
FLUSH PRIVILEGES;

{{- end -}}
{{- end -}}
