{{- define "rondb.imagePullSecrets" -}}
{{- if $.Values.imagePullSecrets }}
imagePullSecrets:
{{- range $.Values.imagePullSecrets }}
  - name: {{ .name }}
{{- end }}
{{- end }}
{{- end }}

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

{{- define "rondb.PodSecurityContext" }}
{{- if $.Values.enableSecurityContext }}
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
{{- end }}
{{- end }}

{{- define "rondb.ContainerSecurityContext" }}
{{- if $.Values.enableSecurityContext }}
securityContext:
  allowPrivilegeEscalation: false
  privileged: false
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: null
  seccompProfile:
    type: RuntimeDefault
{{- end }}
{{- end }}

{{- define "rondb.nodeSelector" -}}
{{- if and .nodeSelector (not (empty .nodeSelector) )}}
nodeSelector: {{ .nodeSelector | toYaml | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "rondb.tolerations" -}}
{{- if and .tolerations (not (empty .tolerations) )}}
tolerations: {{ .tolerations | toYaml | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "rondb.serviceAccountAnnotations" -}}
{{- if $.Values.serviceAccountAnnotations }}
annotations: {{ $.Values.serviceAccountAnnotations | toYaml | nindent 2 }}
{{- end }}
{{- end -}}

{{ define "rondb.storageClass.default" -}}
{{ if .Values.resources.requests.storage.classes.default  }}
storageClassName: {{ .Values.resources.requests.storage.classes.default | quote }}
{{ end }}
{{- end }}

{{ define "rondb.storageClass.mgmd" -}}
{{ if .Values.resources.requests.storage.classes.mgmd }}
storageClassName: {{ .Values.resources.requests.storage.classes.mgmd | quote }}
{{- else }}
{{ include "rondb.storageClass.default" . }}
{{ end }}
{{- end }}

{{ define "rondb.storageClass.diskColumns" -}}
{{ if .Values.resources.requests.storage.classes.diskColumns }}
storageClassName: {{ .Values.resources.requests.storage.classes.diskColumns | quote }}
{{- else }}
{{ include "rondb.storageClass.default" . }}
{{ end }}
{{- end }}

{{ define "rondb.ndbmtd.storageSize" -}}
{{- $ := .root }}
{{- if $.Release.IsInstall }}
{{- $memoryGiB := div $.Values.resources.limits.memory.ndbmtdsMiB 1024 | int }}
{{- $requiredStorage := add 
    (mul $memoryGiB 2.25)
    $.Values.resources.requests.storage.redoLogGiB
    (mul $.Values.resources.requests.storage.undoLogsGiB 2)
    $.Values.resources.requests.storage.logGiB
}}
{{- if not $.Values.resources.requests.storage.classes.diskColumns }}
{{- $requiredStorage := add
  $requiredStorage
  $.Values.resources.requests.storage.diskColumnGiB
}}
{{- end }}
{{- if gt $requiredStorage (int $.Values.resources.requests.storage.ndbmtdGiB) }}
# Validate that the requested storage is enough for the different components
{{ fail (printf "The requested storage size %dGiB is not enough for the ndbmtds. Required: %dGiB" (int $.Values.resources.requests.storage.ndbmtdGiB) $requiredStorage) }}
{{- end }}
  storage: {{ $.Values.resources.requests.storage.ndbmtdGiB | int }}Gi
{{- else }}
{{- $statefulSetName := printf "node-group-%d" .nodeGroup }}
{{- $sts := lookup "apps/v1" "StatefulSet" $.Release.Namespace $statefulSetName }}
{{- if $sts }}
{{- $claim := index $sts.spec.volumeClaimTemplates 0 }}
{{- $size := $claim.spec.resources.requests.storage }}
  storage: {{ $size }} # In case of an upgrade use the existing value
{{- else }}
{{ fail (printf "Failed to lookup StatefulSet %s" $statefulSetName) }}
{{- end }}
{{- end }}
{{- end }}

{{ define "rondb.storageClass.binlogs" -}}
{{ if .Values.resources.requests.storage.classes.binlogFiles }}
storageClassName: {{ .Values.resources.requests.storage.classes.binlogFiles | quote }}
{{- else }}
{{ include "rondb.storageClass.default" . }}
{{ end }}
{{- end }}

{{- define "rondb.container.waitDatanodes" -}}
- name: wait-datanodes-dependency
  image: {{ include "image_address" (dict "image" .Values.images.rondb) }}
{{ include "rondb.ContainerSecurityContext" $ | indent 2 }}
  imagePullPolicy: {{ $.Values.imagePullPolicy }}
  command:
  - /bin/bash
  - -c
  - |
{{ tpl (.Files.Get "files/scripts/wait_ndbmtds.sh") . | indent 4 }}
  env:
  - name: MGMD_HOSTNAME
    value: {{ include "rondb.mgmdHostname" . }}
  resources:
    limits:
      cpu: 0.3
      memory: 100Mi
{{- end }}

{{- define "rondb.container.waitRestore" -}}
{{- if $.Values.restoreFromBackup.backupId }}
- name: wait-restore-backup
  image: {{ include "image_address" (dict "image" $.Values.images.toolbox) }}
  imagePullPolicy: {{ $.Values.imagePullPolicy }}
  command:
  - /bin/bash
  - -c
  - |
    echo "Waiting for restore-backup Job to have completed"
    set -e

    (set -x; kubectl wait \
      -n {{ .Release.Namespace }} \
      --for=condition=complete \
      --timeout={{ .Values.timeoutsMinutes.restoreNativeBackup }}m \
      job/{{ include "rondb.restoreNativeBackupJobname" . }})          

    echo "Restore Job has completed successfully"
  resources:
    limits:
      cpu: 0.3
      memory: 100Mi
{{- end }}
{{- end }}

{{- define "rondb.apiInitContainer" -}}
- name: cluster-dependency-check
  image: {{ include "image_address" (dict "image" .Values.images.rondb) }}
  imagePullPolicy: {{ $.Values.imagePullPolicy }}
  command:
  - /bin/bash
  - -c
  - |
{{ tpl (.Files.Get "files/scripts/apis.sh") . | indent 4 }}
  env:
  - name: MGMD_HOSTNAME
    value: {{ include "rondb.mgmdHostname" . }}
  - name: MYSQLD_SERVICE_HOSTNAME
    value: {{ include "rondb.mysqldServiceHostname" . }}
  - name: MYSQL_CLUSTER_USER
    value: {{ .Values.mysql.clusterUser }}
  - name: MYSQL_CLUSTER_PASSWORD
    valueFrom:
      secretKeyRef:
        key: {{ .Values.mysql.clusterUser }}
        name: {{ $.Values.mysql.credentialsSecretName }}
{{- end }}

{{- define "rondb.arrayToCsv" -}}
{{- if .array }}
{{- $length := len .array -}}
{{- range $index, $element := .array -}}
{{- $element }}{{- if lt $index (sub $length 1) }},{{ end -}}
{{- end }}
{{- end }}
{{- end }}

{{- define "rondb.takeBackupPathPrefix" }}
{{- .Values.backups.pathPrefix | default "rondb_backup" }}
{{- end }}

{{- define "rondb.restoreBackupPathPrefix" }}
{{- .Values.restoreFromBackup.pathPrefix | default "rondb_backup" }}
{{- end }}

{{- define "rondb.affinity.preferred.ndbdAZs" }}
# Try to place Pods into same AZs as data nodes for low latency
- weight: 90
  podAffinityTerm:
    topologyKey: topology.kubernetes.io/zone
    labelSelector:
      matchExpressions:
      - key: nodeGroup
        operator: In
        values:
{{- range $nodeGroup := until ($.Values.clusterSize.numNodeGroups | int) }}
        - {{ $nodeGroup | quote }}
{{ end }}
{{- end }}


# Previously JOB_NUMBER=$(echo $JOB_NAME | tr -d '[[:alpha:]]' | tr -d '-' | sed 's/^0*//' | cut -c -9)
# However, sometimes, the JOB_NAME would not contain an integer
# Now, we hash the JOB_NAME, remove alphabets and take the first 5 characters
# echo -n "$JOB_NAME" | sha1sum                     # Hash
# echo -n "$JOB_NAME" | ... | cut -d ' ' -f 1       # Remove appended whitespace
# echo -n "$JOB_NAME" | ... | xxd -p                # Hexadecimal hash
# echo -n "$JOB_NAME" | ... | tr -d '\n'            # Remove newline
# echo -n "$JOB_NAME" | ... | tr -d '[[:alpha:]]'   # Remove alphabets
# echo -n "$JOB_NAME" | ... | sed 's/^0*//'         # Remove appended zeroes
# echo -n "$JOB_NAME" | ... | cut -c 1-5            # Truncate to 5 characters
{{- define "rondb.backups.defineJobNumberEnv" }}
JOB_NUMBER=$(echo -n "$JOB_NAME" | sha1sum | cut -d ' ' -f 1 | tr -d '\n' | tr -d '[[:alpha:]]' | sed 's/^0*//' | cut -c 1-5)
if [ -z "$JOB_NUMBER" ]; then
    echo "JOB_NUMBER is not set"
    exit 1
fi
echo "Job number: $JOB_NUMBER"
{{- end }}

{{- define "rondb.certManager.certificate.endToEnd" }}
{{- if and 
    .endToEndTls.enabled 
    (not .endToEndTls.supplyOwnSecret)
}}
# Certificates will prompt the cert-manager to create a TLS Secret using the referenced
# Issuer.
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ required "A Certificate must specify a name" .certName }}
  namespace: {{ $.Release.Namespace }}
spec:
  secretName: {{ .endToEndTls.secretName }}
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  dnsNames:
{{ required "A Certificate must contain dnsNames" .dnsNames | toYaml | indent 4 }}
  issuerRef:
    name: {{ include "rondb.certManager.issuer" $ }}
    kind: Issuer
---
{{ end }}
{{- end }}

# This is an easy way to trigger rolling restarts of all RonDB Pods
{{- define "rondb.configIniHash" -}}
{{ mustRegexReplaceAll "NodeActive *=.*" (tpl ($.Files.Get "files/configs/config.ini") $) "" | sha256sum }}
{{- end -}}

# MaxDMLOperationsPerTransaction cannot exceed MaxNoOfConcurrentOperations
{{- define "rondb.validatedMaxDMLOperationsPerTransaction" -}}
{{- $dml := (.Values.rondbConfig.MaxDMLOperationsPerTransaction | default 32768) | int -}}
{{- $conc := (.Values.rondbConfig.MaxNoOfConcurrentOperations | default 65536) | int -}}
{{- if le $dml $conc }}
{{- $dml -}}
{{- end -}}
{{- end -}}

{{- define "rondb.isAWS" -}}
{{- if and .Values.global .Values.global._hopsworks (eq (upper .Values.global._hopsworks.cloudProvider) "AWS") -}}
true
{{- end -}}
{{- end -}}

{{- define "rondb.isExternallyManaged" -}}
{{- if and .Values.global .Values.global._hopsworks.externalServices .Values.global._hopsworks.externalServices.rondb .Values.global._hopsworks.externalServices.rondb.external -}}
true
{{- end -}}
{{- end -}}

{{- define "rondb.backup.credentials" -}}
{{- if or (eq .backupConfig.objectStorageProvider "s3") (include "rondb.globalObjectStorage.s3" .)}}
{{- $secretName := "" }}
{{- $key := "" }}
{{- if and .backupConfig.s3.keyCredentialsSecret.name .backupConfig.s3.keyCredentialsSecret.key }}
{{- $secretName = .backupConfig.s3.keyCredentialsSecret.name }}
{{- $key = .backupConfig.s3.keyCredentialsSecret.key  }}
{{- else if and (include "rondb.globalObjectStorage.s3" .) .global._hopsworks.managedObjectStorage.s3.secret .global._hopsworks.managedObjectStorage.s3.secret.name .global._hopsworks.managedObjectStorage.s3.secret.acess_key_id}}
{{- $secretName = .global._hopsworks.managedObjectStorage.s3.secret.name }}
{{- $key = .global._hopsworks.managedObjectStorage.s3.secret.acess_key_id }}
{{- end }}
{{- if (lookup "v1" "Secret" .namespace $secretName ) }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $key }}
{{- end }}
{{- if and .backupConfig.s3.secretCredentialsSecret.name .backupConfig.s3.secretCredentialsSecret.key }}
{{- $secretName = .backupConfig.s3.secretCredentialsSecret.name }}
{{- $key = .backupConfig.s3.secretCredentialsSecret.key  }}
{{- else if and (include "rondb.globalObjectStorage.s3" .) .global._hopsworks.managedObjectStorage.s3.secret .global._hopsworks.managedObjectStorage.s3.secret.name .global._hopsworks.managedObjectStorage.s3.secret.secret_key_id}}
{{- $secretName = .global._hopsworks.managedObjectStorage.s3.secret.name }}
{{- $key = .global._hopsworks.managedObjectStorage.s3.secret.secret_key_id }}
{{- end }}
{{- if (lookup "v1" "Secret" .namespace $secretName) }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $key }}
{{- end }}
{{- end }}
{{- end -}}

# FIXME need to account for minio as well if enabled 

{{- define "rondb.globalObjectStorage" -}}
{{- if and .global .global._hopsworks .global._hopsworks.managedObjectStorage .global._hopsworks.managedObjectStorage.enabled -}}
true
{{- end -}}
{{- end -}}

{{- define "rondb.globalObjectStorage.s3" -}}
{{- if and (include "rondb.globalObjectStorage" .) .global._hopsworks.managedObjectStorage.s3  -}}
true
{{- end -}}
{{- end -}}

{{- define "rondb.globalObjectStorage.backupsEnabled" -}}
{{- if and (include  "rondb.globalObjectStorage" (dict "global" .Values.global)) .Values.global._hopsworks.managedObjectStorage.backups .Values.global._hopsworks.managedObjectStorage.backups.enabled -}}
true
{{- end -}}
{{- end -}}

{{- define "rondb.backups.isEnabled" -}}
{{- if or .Values.backups.enabled (include "rondb.globalObjectStorage.backupsEnabled" .) -}}
true
{{- end -}}
{{- end -}}

# FIXME add a default value
{{- define "rondb.backups.schedule" -}}
{{- if .Values.backups.schedule -}}
{{- .Values.backups.schedule -}}
{{- else if and (include "rondb.globalObjectStorage.backupsEnabled" .) .Values.global._hopsworks.managedObjectStorage.backups.schedule -}}
{{- .Values.global._hopsworks.managedObjectStorage.backups.schedule -}}
{{- end -}}
{{- end -}}

{{- define "rondb.backups.bucketName" -}}
{{- if .backupConfig.s3.bucketName -}}
{{- .backupConfig.s3.bucketName -}}
{{- else if and (include "rondb.globalObjectStorage.s3" .) .global._hopsworks.managedObjectStorage.s3.bucket.name -}}
{{- .global._hopsworks.managedObjectStorage.s3.bucket.name -}}
{{- else -}}
{{- fail "Missing bucket name configuration for backups. Please specify the bucket name either in the Rondb subchart or under global._hopsworks.managedObjectStorage." }}
{{- end -}}
{{- end -}}


{{- define "rondb.rcloneConfig" -}}
{{- if or (eq .backupConfig.objectStorageProvider "s3") (include "rondb.globalObjectStorage.s3" .) }}
type = s3
env_auth = true
storage_class = STANDARD
{{- if .backupConfig.s3.provider }}
provider = {{ .backupConfig.s3.provider }}
{{- else if and .global._hopsworks (eq (upper .global._hopsworks.cloudProvider) "AWS")}}
provider = AWS
{{- else }}
provider = Other
{{- end }}
{{- if .backupConfig.s3.region }}
region = {{ .backupConfig.s3.region }}
{{- else if and (include "rondb.globalObjectStorage.s3" .) .global._hopsworks.managedObjectStorage.s3.region }}
region = {{ .global._hopsworks.managedObjectStorage.s3.region }}
{{- end }}
{{- if .backupConfig.s3.serverSideEncryption }}
server_side_encryption = {{ .backupConfig.s3.serverSideEncryption }}
{{- else if and (include "rondb.globalObjectStorage.s3" .) .global._hopsworks.managedObjectStorage.s3.serverSideEncryption }}
server_side_encryption = {{ .global._hopsworks.managedObjectStorage.s3.serverSideEncryption }}
{{- end }}
{{- if .backupConfig.s3.endpoint }}
endpoint = {{ .backupConfig.s3.endpoint }}
{{- else if and (include "rondb.globalObjectStorage.s3" .) .global._hopsworks.managedObjectStorage.s3.endpoint }}
endpoint = {{ .global._hopsworks.managedObjectStorage.s3.endpoint }}
{{- end }}
{{- end }}
{{- end -}}