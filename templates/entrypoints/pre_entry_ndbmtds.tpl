# Calculate Node Id based on Pod name and Node Group

{{ define "pre_entrypoint_ndbmtds" }}
#!/bin/bash

set -e

# Equivalent to replication factor of pod
POD_ID=$(echo $POD_NAME | grep -o '[0-9]\+$')

echo "[K8s Entrypoint ndbmtd] Running Pod ID: $POD_ID in Node Group: $NODE_GROUP"

NODE_ID_OFFSET=$(($NODE_GROUP*3))
NODE_ID=$(($NODE_ID_OFFSET+$POD_ID+1))

echo "[K8s Entrypoint ndbmtd] Running Node Id: $NODE_ID"

INITIAL_START=
# This is the first file that is read by the ndbmtd
FIRST_FILE_READ=$FILE_SYSTEM_PATH/ndb_${NODE_ID}_fs/D1/DBDIH/P0.sysfile
if [ ! -f "$FIRST_FILE_READ" ]
then
    echo "[K8s Entrypoint ndbmtd] The file $FIRST_FILE_READ does not exist - we'll do an initial start here"
    INITIAL_START="--initial"
else
    echo "[K8s Entrypoint ndbmtd] The file $FIRST_FILE_READ exists - we have started the ndbmtds here before. No initial start is needed."
fi

exec ndbmtd --nodaemon --ndb-nodeid=$NODE_ID $INITIAL_START --ndb-connectstring=$MGM_CONNECTION_STRING
{{ end }}
