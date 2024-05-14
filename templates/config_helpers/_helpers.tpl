# Could be that there is no repository (e.g. docker.io/alpine)
{{- define "image_repository" -}}
{{- if or (not .image.repository) (eq .image.repository "") -}}
{{- else -}}
{{ .image.repository }}/
{{- end -}}
{{- end -}}

{{- define "image_address" -}}
{{ .image.registry }}/{{ include "image_repository" (dict "image" .image ) }}{{ .image.name }}:{{ .image.tag }}
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
DELIMITER //
CREATE DATABASE IF NOT EXISTS dbs_have_initialized;
USE dbs_have_initialized;
CREATE PROCEDURE IF NOT EXISTS initDBS()
BEGIN

  DECLARE table_count INT;

  SELECT COUNT(*) INTO table_count FROM information_schema.tables WHERE table_schema = 'dbs_have_initialized' and table_name='initialized_flag';

  IF table_count = 0 THEN

{{- range $k, $v := .Values.mysql.sqlInitContent }}
{{ $v | indent 4 }}
{{- end }}

{{- if and .Values.global .Values.global.mysql.user .Values.global.mysql.password .Values.global.mysql.grant_on_host }}
    CREATE USER IF NOT EXISTS '{{ .Values.global.mysql.user }}'@'{{ .Values.global.mysql.grant_on_host }}' IDENTIFIED WITH mysql_native_password BY '{{ .Values.global.mysql.password }}';
    GRANT ALL PRIVILEGES ON *.* TO '{{ .Values.global.mysql.user }}'@'{{ .Values.global.mysql.grant_on_host }}' WITH GRANT OPTION;
    -- Save user in RonDB (to access them on any MySQLd)
    GRANT NDB_STORED_USER ON *.* TO '{{ .Values.global.mysql.user }}'@'{{ .Values.global.mysql.grant_on_host }}';
    FLUSH PRIVILEGES;
{{- end }}
    
    CREATE TABLE IF NOT EXISTS initialized_flag ( ignore_col int);

  END IF;
END //
DELIMITER ;
CALL initDBS();

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

{{- define "rondb.storageClassName" -}}
{{- if and $.Values.global $.Values.global.storageClassName -}}
storageClassName: {{  $.Values.global.storageClassName | quote }}
{{- else if $.Values.resources.requests.storage.storageClassName -}}
storageClassName: {{  $.Values.resources.requests.storage.storageClassName | quote }}
{{- end -}}
{{- end -}}

{{- define "rondb.diskColumn.storageClassName" -}}
{{- if and $.Values.global $.Values.global.storageClassName -}}
storageClassName: {{  $.Values.global.storageClassName | quote }}
{{- else if $.Values.resources.requests.storage.dedicatedDiskColumnVolume.storageClassName -}}
storageClassName: {{  $.Values.resources.requests.storage.dedicatedDiskColumnVolume.storageClassName | quote }}
{{- end -}}
{{- end -}}

{{- define "rondb.apiInitContainer" -}}
- name: cluster-dependency-check
  image: {{ include "image_address" (dict "image" .Values.images.rondb) }}
  command:
  - /bin/bash
  - -c
  - |
{{ tpl (.Files.Get "files/entrypoints/apis.sh") . | indent 4 }}
  env:
  - name: MGMD_HOSTNAME
    value: {{ .Values.meta.mgmd.statefulSetName }}-0.{{ .Values.meta.mgmd.headlessClusterIp.name }}.{{ .Release.Namespace }}.svc.cluster.local
  - name: MYSQLD_SERVICE_HOSTNAME
    value: {{ .Values.meta.mysqld.service.name }}.{{ .Release.Namespace }}.svc.cluster.local
  - name: MYSQL_BENCH_USER
    value: {{ .Values.benchmarking.mysqlUsername }}
  - name: MYSQL_BENCH_PASSWORD
    valueFrom:
      secretKeyRef:
        {{- toYaml .Values.benchmarking.credentialsSecret | nindent 8 }}
{{- end }}
