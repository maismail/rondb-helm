#!/bin/bash

# Note: This ignores the main.sh script; Not very important when running with volumes though

set -e

# https://stackoverflow.com/a/246128/9068781
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

###################
# SED MY.CNF FILE #
###################

# Calculate Node Ids based on Pod name & sed my.cnf file

RAW_MYCNF_FILEPATH=/srv/hops/mysql-cluster/my-raw.cnf
MYCNF_FILEPATH=$RONDB_DATA_DIR/my.cnf

cp $RAW_MYCNF_FILEPATH $MYCNF_FILEPATH

# Equivalent to replication factor of pod
MYSQLD_NR=$(echo $POD_NAME | grep -o '[0-9]\+$')

echo "[K8s Entrypoint MySQLd] Running MySQLd nr. $MYSQLD_NR with $CONNECTIONS_PER_MYSQLD connections"

FIRST_NODE_ID=$((67+($MYSQLD_NR*$CONNECTIONS_PER_MYSQLD)))
LAST_NODE_ID=$(($FIRST_NODE_ID+$CONNECTIONS_PER_MYSQLD-1))

NODES_SEQ=$(seq -s, $FIRST_NODE_ID $LAST_NODE_ID)

echo "[K8s Entrypoint MySQLd] Running Node Ids: $NODES_SEQ"

# Replace the existing lines in my.cnf
sed -i "/ndb-cluster-connection-pool-nodeids/c\ndb-cluster-connection-pool-nodeids=$NODES_SEQ" $MYCNF_FILEPATH
# Note that this is used for liveliness/readiness probes
sed -i "/^[ ]*password[ ]*=/c\password=$MYSQL_BENCH_PASSWORD" $MYCNF_FILEPATH

###############################
# CHECK OUR DNS IS RESOLVABLE #
###############################

# We need this, otherwise the MGMd will not recognise our IP address
# when we try to connect at startup.

OWN_HOSTNAME="{{ $.Values.meta.mysqld.statefulSetName }}-$MYSQLD_NR.{{ $.Values.meta.mysqld.headlessClusterIp.name }}.{{ $.Release.Namespace }}.svc.cluster.local"
until nslookup $OWN_HOSTNAME; do
    echo "[K8s Entrypoint MySQLd] Waiting for $OWN_HOSTNAME to be resolvable..."
    sleep $(((RANDOM % 2)+2))
done

###########################################
# CONFIGURE MYSQLD & INITIALIZE DATABASES #
###########################################

source ./docker/rondb_standalone/entrypoints/mysqld_configure.sh ""

if [[ $POD_NAME != *"-0" ]]; then
    echo "[K8s Entrypoint MySQLd] Not initializing MySQL databases because this is not the first MySQLd pod"
else
    echo "[K8s Entrypoint MySQLd] initializing MySQL databases"
    source ./docker/rondb_standalone/entrypoints/mysqld_init_db.sh "$@"
fi

echo "[K8s Entrypoint MySQLd] Ready for starting up MySQLd"
echo "[K8s Entrypoint MySQLd] Running: $*"
exec "$@"
