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
