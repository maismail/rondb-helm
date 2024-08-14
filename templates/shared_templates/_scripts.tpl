{{- define "rondb.nodeId" -}}
# Equivalent to replication factor of pod
POD_ID=$(echo $POD_NAME | grep -o '[0-9]\+$')
NODE_ID_OFFSET=$(($NODE_GROUP*3))
NODE_ID=$(($NODE_ID_OFFSET+$POD_ID+1))
{{- end -}}

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
