# Also supports nothing defined at all (local registry)
{{- define "image_registry" -}}
{{- if and $.Values.global $.Values.global.imageRegistry -}}
{{- $.Values.global.imageRegistry -}}/hopsworks/
{{- else if $.Values.image.registry -}}
{{- $.Values.image.registry -}}/hopsworks/
{{- end -}}
{{- end -}}

{{- define "rondb.nodeId" -}}
# Equivalent to replication factor of pod
POD_ID=$(echo $POD_NAME | grep -o '[0-9]\+$')
NODE_ID_OFFSET=$(($NODE_GROUP*3))
NODE_ID=$(($NODE_ID_OFFSET+$POD_ID+1))
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

{{- define "rondb.SecurityContext" -}}
# This corresponds to the MySQL user/group which is created in the Dockerfile
# Beware that a lot of files & directories are created in the RonDB Dockerfile, which belong
# to the MySQL user/group.
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
{{- end }}
