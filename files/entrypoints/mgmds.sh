#!/bin/bash

# The configuration database is a binary representation of the cluster's configuration.
# It is essentially the config.ini including all changes that were applied via the
# management client (ndb_mgm).

INITIAL_ARG=
CONFIG_DB_DIR=/srv/hops/mysql-cluster/mgmd
FOUND_FILES=$(find "$CONFIG_DB_DIR" -type f -name "*config.bin.*")
NUM_FOUND=$(echo "$FOUND_FILES" | grep -c .)
if [ "$NUM_FOUND" -lt 1 ]; then
    echo "No configuration database available. Doing an initial start."
    INITIAL_ARG="--initial"
else
    echo "A configuration database was found. Not running an initial start."
fi

ndb_mgmd $INITIAL_ARG \
    --nodaemon \
    --ndb-nodeid=65 \
    -f "$RONDB_DATA_DIR/config.ini" \
    --configdir="$CONFIG_DB_DIR"
