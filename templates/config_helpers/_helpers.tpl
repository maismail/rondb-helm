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

{{- define "rondb.toolboxImage" -}}
{{- if and .Values.global .Values.global._hopsworks .Values.global._hopsworks.toolbox }}
{{- include "hopsworkslib.toolboxImage" (dict "Values" .Values "default" .default) }}
{{- else -}}
{{ include "image_address" (dict "image" .Values.images.toolbox) }}
{{- end -}}
{{- end -}}

{{- define "rondb.nodeId" -}}
# Equivalent to replication factor of pod
POD_ID=$(echo $POD_NAME | grep -o '[0-9]\+$')
NODE_ID_OFFSET=$(($NODE_GROUP*3))
NODE_ID=$(($NODE_ID_OFFSET+$POD_ID+1))
{{- end -}}

{{/*
- Run all custom SQL init files
*/}}
{{- define "rondb.sqlInitContent" -}}
{{- range $k, $v := .Values.mysql.sqlInitContent }}
{{ $v | indent 4 }}
{{- end }}
{{- end -}}

{{- define "rondb.SecurityContext" }}
# This corresponds to the MySQL user/group which is created in the Dockerfile
# Beware that a lot of files & directories are created in the RonDB Dockerfile, which belong
# to the MySQL user/group.
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
{{- end }}

{{- define "rondb.storageClassName" -}}
{{- if .Values.resources.requests.storage.storageClassName -}}
storageClassName: {{  .Values.resources.requests.storage.storageClassName | quote }}
{{- else if and .Values.global .Values.global._hopsworks .Values.global._hopsworks.storageClassName -}}
storageClassName: {{  .Values.global._hopsworks.storageClassName | quote }}
{{- end -}}
{{- end -}}

{{- define "rondb.diskColumn.storageClassName" -}}
{{- if .Values.resources.requests.storage.dedicatedDiskColumnVolume.storageClassName -}}
storageClassName: {{  .Values.resources.requests.storage.dedicatedDiskColumnVolume.storageClassName | quote }}
{{- else if and .Values.global .Values.global._hopsworks .Values.global._hopsworks.storageClassName -}}
storageClassName: {{  .Values.global._hopsworks.storageClassName | quote }}
{{- end -}}
{{- end -}}

{{- define "rondb.waitDatanodes" -}}
- name: wait-datanodes-dependency
  image: {{ include "image_address" (dict "image" .Values.images.rondb) }}
  imagePullPolicy: {{ include "hopsworkslib.imagePullPolicy" . | default "IfNotPresent" }}
  command:
  - /bin/bash
  - -c
  - |
{{ tpl (.Files.Get "files/entrypoints/wait_ndbmtds.sh") . | indent 4 }}
  env:
  - name: MGMD_HOSTNAME
    value: {{ include "rondb.mgmdHostname" . }}
  resources:
    limits:
      cpu: 0.3
      memory: 100Mi
{{- end }}

{{- define "rondb.apiInitContainer" -}}
- name: cluster-dependency-check
  image: {{ include "image_address" (dict "image" .Values.images.rondb) }}
  imagePullPolicy: {{ include "hopsworkslib.imagePullPolicy" . | default "IfNotPresent" }}
  command:
  - /bin/bash
  - -c
  - |
{{ tpl (.Files.Get "files/entrypoints/apis.sh") . | indent 4 }}
  env:
  - name: MGMD_HOSTNAME
    value: {{ include "rondb.mgmdHostname" . }}
  - name: MYSQLD_SERVICE_HOSTNAME
    value: {{ include "rondb.mysqldServiceHostname" . }}
  - name: MYSQL_BENCH_USER
    value: {{ .Values.benchmarking.mysqlUsername }}
  - name: MYSQL_BENCH_PASSWORD
    valueFrom:
      secretKeyRef:
        key: {{ .Values.benchmarking.mysqlUsername }}
        name: {{ include "rondb.mysql.usersSecretName" . }}
{{- end }}

{{- define "rondb.createRcloneConfig" -}}
echo "Location of rclone config file:"
rclone config file

echo "Templating file $RCLONE_MOUNT_FILEPATH to $RCLONE_CONFIG"
cp $RCLONE_MOUNT_FILEPATH $RCLONE_CONFIG

# Helper function to escape special characters in the variable
escape_sed() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}

{{- if eq $.Values.restoreFromBackup.objectStorageProvider "s3" }}
# Escape the variables
ESCAPED_ACCESS_KEY_ID=$(escape_sed "$ACCESS_KEY_ID")
ESCAPED_SECRET_ACCESS_KEY=$(escape_sed "$SECRET_ACCESS_KEY")

sed -i "s|REG_ACCESS_KEY_ID|$ESCAPED_ACCESS_KEY_ID|g" "$RCLONE_CONFIG"
sed -i "s|REG_SECRET_ACCESS_KEY|$ESCAPED_SECRET_ACCESS_KEY|g" "$RCLONE_CONFIG"
{{- end }}
{{- end }}

{{- define "rondb.sedMyCnfFile" -}}
{{/*
    Only run this on MySQLd Stateful Set container
*/}}
###################
# SED MY.CNF FILE #
###################

RAW_MYCNF_FILEPATH=$RONDB_DATA_DIR/my-raw.cnf
MYCNF_FILEPATH=$RONDB_DATA_DIR/my.cnf
cp $RAW_MYCNF_FILEPATH $MYCNF_FILEPATH

# Calculate Node Ids based on Pod name
# Pod name is equivalent to replication factor of pod
MYSQLD_NR=$(echo $POD_NAME | grep -o '[0-9]\+$')
FIRST_NODE_ID=$((67 + ($MYSQLD_NR * $CONNECTIONS_PER_MYSQLD)))
LAST_NODE_ID=$(($FIRST_NODE_ID + $CONNECTIONS_PER_MYSQLD - 1))
NODES_SEQ=$(seq -s, $FIRST_NODE_ID $LAST_NODE_ID)
echo "[K8s Entrypoint MySQLd] Running MySQLd nr. $MYSQLD_NR with $CONNECTIONS_PER_MYSQLD connections using node ids: $NODES_SEQ"

# Replace the existing lines in my.cnf
sed -i "/ndb-cluster-connection-pool\s*=/c\ndb-cluster-connection-pool=$CONNECTIONS_PER_MYSQLD" $MYCNF_FILEPATH
sed -i "/ndb-cluster-connection-pool-nodeids/c\ndb-cluster-connection-pool-nodeids=$NODES_SEQ" $MYCNF_FILEPATH
# Note that this is used for liveliness/readiness probes
sed -i "/^[ ]*password[ ]*=/c\password=$MYSQL_BENCH_PASSWORD" $MYCNF_FILEPATH
{{- end }}

{{- define "rondb.initializeMySQLd" -}}
####################
# CONFIGURE MYSQLD #
####################

CMD=("mysqld" "--defaults-file=$MYCNF_FILEPATH")

echo && echo "[K8s Entrypoint MySQLd] Validating config file" && echo
(
    set -x
    "${CMD[@]}" --validate-config
)

echo && echo "[K8s Entrypoint MySQLd] Initializing MySQLd" && echo
(
    set -x
    "${CMD[@]}" \
        --log-error-verbosity=3 \
        --initialize-insecure \
        --explicit_defaults_for_timestamp
)

echo && echo "[K8s Entrypoint MySQLd] Successfully initialized MySQLd" && echo
{{- end }}

{{- define "rondb.mapNewNodesToBackedUpNodes" -}}
{{ include "rondb.createRcloneConfig" $ }}

{{- if eq $.Values.restoreFromBackup.objectStorageProvider "s3" }}
REMOTE_NATIVE_BACKUP_DIR={{ include "rondb.rcloneRestoreRemoteName" . }}:{{ $.Values.restoreFromBackup.s3.bucketName }}/$BACKUP_ID/rondb
echo "Path of remote (native) backup: $REMOTE_NATIVE_BACKUP_DIR"
{{- end }}

DIRECTORY_NAMES=$(rclone lsd $REMOTE_NATIVE_BACKUP_DIR | awk '{print $NF}')
OLD_NODE_IDS=($DIRECTORY_NAMES)
echo "Old node IDs: ${OLD_NODE_IDS[@]}"

{{ $activeNodeIds := list }}
{{- range $nodeGroup := until ($.Values.clusterSize.numNodeGroups | int) -}}
    {{- range $replica := until 3 -}}
        {{- if ge $replica ($.Values.clusterSize.activeDataReplicas | int) -}}
            {{- continue -}}
        {{- end -}}
        {{- $offset := ( mul $nodeGroup 3) -}}
        {{- $nodeId := ( add $offset (add $replica 1)) -}}
        {{ $activeNodeIds = append $activeNodeIds $nodeId }}
    {{- end -}}
{{- end -}}
# These are only the currently active node IDs
NEW_NODE_IDS=({{ range $i, $e := $activeNodeIds }}{{ if $i }} {{ end }}{{ $e }}{{ end }})
echo "Currently active data node IDs: ${NEW_NODE_IDS[@]}"

# Map old node IDs to new node IDs
declare -A MAP_NODE_IDS
for NEW_NODE_ID in "${NEW_NODE_IDS[@]}"; do
    MAP_NODE_IDS[$NEW_NODE_ID]=""
done

# Distribute OLD_NODE_IDS among NEW_NODE_IDS
NUM_NEW_NODES=${#NEW_NODE_IDS[@]}
for IDX_OLD_NODE_ID in "${!OLD_NODE_IDS[@]}"; do
    OLD_NODE_ID=${OLD_NODE_IDS[$IDX_OLD_NODE_ID]}
    IDX_NEW_NODE=$((IDX_OLD_NODE_ID % $NUM_NEW_NODES))
    RESPONSIBLE_NODE_ID=${NEW_NODE_IDS[$IDX_NEW_NODE]}
    MAP_NODE_IDS[$RESPONSIBLE_NODE_ID]+="$OLD_NODE_ID "
done

# Print the result
for NEW_NODE_ID in "${!MAP_NODE_IDS[@]}"; do
    echo "New node ID '$NEW_NODE_ID' is restoring these old node IDs: ${MAP_NODE_IDS[$NEW_NODE_ID]}"
done
{{- end }}

{{- define "rondb.arrayToCsv" -}}
{{- if .array }}
{{- $length := len .array -}}
{{- range $index, $element := .array -}}
{{- $element }}{{- if lt $index (sub $length 1) }},{{ end -}}
{{- end }}
{{- end }}
{{- end }}

{{/*
- Create Hopsworks root user
*/}}
{{- define "rondb.createHopsworksRootUser" -}}
{{- if and .Values.global .Values.global._hopsworks }}
{{ $grantOnHost := "%" }}
CREATE USER IF NOT EXISTS '{{ include "hopsworkslib.mysql.hopsworksRootUser" . }}'@'{{ $grantOnHost }}' IDENTIFIED WITH mysql_native_password BY '$MYSQL_HOPSWORKS_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '{{ include "hopsworkslib.mysql.hopsworksRootUser" . }}'@'{{ $grantOnHost }}' WITH GRANT OPTION;
GRANT NDB_STORED_USER ON *.*TO '{{include "hopsworkslib.mysql.hopsworksRootUser" . }}'@'{{ $grantOnHost }}';
FLUSH PRIVILEGES;
{{- end }}
{{- end -}}


{{- define "rondb.mysql.usersSecretName" -}}
{{- if and .Values.global .Values.global._hopsworks -}}
{{ include "hopsworkslib.mysql.usersSecretName" . }}
{{- else -}}
{{ .Values.mysql.credentialsSecretName }}
{{- end -}}
{{- end -}}