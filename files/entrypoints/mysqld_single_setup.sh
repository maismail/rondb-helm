set -e

echo_newline() { echo; echo "$1"; echo; }

###################
# SED MY.CNF FILE #
###################

RAW_MYCNF_FILEPATH=/srv/hops/mysql-cluster/my-raw.cnf
MYCNF_FILEPATH=$RONDB_DATA_DIR/my.cnf
cp $RAW_MYCNF_FILEPATH $MYCNF_FILEPATH

# Take a single empty slot
sed -i "/ndb-cluster-connection-pool/c\# ndb-cluster-connection-pool=1" $MYCNF_FILEPATH
sed -i "/ndb-cluster-connection-pool-nodeids/c\# ndb-cluster-connection-pool-nodeids" $MYCNF_FILEPATH

##################################
# MOVE OVER RESTORE-BACKUP FILES #
##################################

# In case nothing is restored, create the directory
RESTORE_SCRIPTS_DIR={{ include "rondb.sqlRestoreScriptsDir" . }}
mkdir -p $RESTORE_SCRIPTS_DIR
echo_newline "[K8s Entrypoint MySQLd] Directory for MySQL schemata to *restore*: '$RESTORE_SCRIPTS_DIR'"
(
    set -x
    ls -la $RESTORE_SCRIPTS_DIR
)

{{ include "rondb.initializeMySQLd" . }}

########################
# INITIALIZE DATABASES #
########################

echo_newline "[K8s Entrypoint MySQLd] Running MySQLd as background-process in socket-only mode for initialization"
(
    set -x
    "${CMD[@]}" \
        --log-error-verbosity=3 \
        --skip-networking \
        --daemonize
)

echo_newline "[K8s Entrypoint MySQLd] Pinging MySQLd..."
SOCKET=/srv/hops/mysql-cluster/mysql.sock
attempt=0
max_attempts=30
until mysqladmin --socket="$SOCKET" ping --silent --connect-timeout=2; do
    echo_newline "[K8s Entrypoint MySQLd] Failed pinging MySQLd on attempt $attempt" && sleep 1
    attempt=$((attempt + 1))
    if [[ $attempt -gt $max_attempts ]]; then
        echo_newline "[K8s Entrypoint MySQLd] Failed pinging MySQLd after $max_attempts attempts" && exit 1
    fi
done

echo_newline "[K8s Entryoint MySQLd] MySQLd is up and running"

###############################
### SETUP USERS & PASSWORDS ###
###############################

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo >&2 '[K8s Entrypoint MySQLd] No password option specified for root user.'
    exit 1
fi

# Defining the client command used throughout the script
# Since networking is not permitted for this mysql server, we have to use a socket to connect to it
# "SET @@SESSION.SQL_LOG_BIN=0;" is required for products like group replication to work properly
DUMMY_ROOT_PASSWORD=
function mysql() { command mysql -uroot -hlocalhost --password="$DUMMY_ROOT_PASSWORD" --protocol=socket --socket="$SOCKET" --init-command="SET @@SESSION.SQL_LOG_BIN=0;"; }

echo_newline '[K8s Entrypoint MySQLd] Changing the root user password'
mysql <<EOF
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
    GRANT NDB_STORED_USER ON *.* TO 'root'@'localhost';
    FLUSH PRIVILEGES;
EOF

DUMMY_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD

####################################
### SETUP BENCHMARKING DATABASES ###
####################################

# Benchmarking table; all other tables will be created by the benchmakrs themselves
echo "CREATE DATABASE IF NOT EXISTS \`dbt2\` ;" | mysql
echo "CREATE DATABASE IF NOT EXISTS \`ycsb\` ;" | mysql

# shellcheck disable=SC2153
if [ "$MYSQL_BENCH_USER" ]; then
    echo_newline "[K8s Entrypoint MySQLd] Initializing benchmarking user $MYSQL_BENCH_USER"

    echo "CREATE USER IF NOT EXISTS '$MYSQL_BENCH_USER'@'%' IDENTIFIED BY '$MYSQL_BENCH_PASSWORD' ;" | mysql

    # Grant MYSQL_BENCH_USER rights to all benchmarking databases
    echo "GRANT NDB_STORED_USER ON *.* TO '$MYSQL_BENCH_USER'@'%' ;" | mysql
    echo "GRANT ALL PRIVILEGES ON \`sysbench%\`.* TO '$MYSQL_BENCH_USER'@'%' ;" | mysql
    echo "GRANT ALL PRIVILEGES ON \`dbt%\`.* TO '$MYSQL_BENCH_USER'@'%' ;" | mysql
    echo "GRANT ALL PRIVILEGES ON \`sbtest%\`.* TO '$MYSQL_BENCH_USER'@'%' ;" | mysql
    echo "GRANT ALL PRIVILEGES ON \`ycsb%\`.* TO '$MYSQL_BENCH_USER'@'%' ;" | mysql
else
    echo_newline '[K8s Entrypoint MySQLd] Not creating benchmark user. MYSQL_BENCH_USER and MYSQL_BENCH_PASSWORD must be specified to do so.'
fi

##############################
### RUN CUSTOM SQL SCRIPTS ###
##############################

# TODO: Move sedding logic in backup(?)

SED_CREATE_TABLE="s/CREATE TABLE( IF NOT EXISTS)? /CREATE TABLE IF NOT EXISTS /g"
SED_CREATE_USER="s/CREATE USER( IF NOT EXISTS)? /CREATE USER IF NOT EXISTS /g"

echo_newline "[K8s Entrypoint MySQLd] Running MySQL restore scripts from '$RESTORE_SCRIPTS_DIR' (if available)"
for f in $RESTORE_SCRIPTS_DIR/*; do
    case "$f" in
    *.sql)
        echo_newline "[K8s Entrypoint MySQLd] Running $f"
        cat $f | sed -E "$SED_CREATE_TABLE" | sed -E "$SED_CREATE_USER" | mysql
        ;;
    *) echo_newline "[K8s Entrypoint MySQLd] Ignoring $f" ;;
    esac
done

INIT_SCRIPTS_DIR={{ include "rondb.sqlInitScriptsDir" . }}
echo_newline "[K8s Entrypoint MySQLd] Running user-supplied MySQL init-scripts from '$INIT_SCRIPTS_DIR'"
for f in $INIT_SCRIPTS_DIR/*; do
    case "$f" in
    *.sql)
        echo_newline "[K8s Entrypoint MySQLd] Running $f"
        cat $f | sed -E "$SED_CREATE_TABLE" | sed -E "$SED_CREATE_USER" | mysql
        ;;
    *) echo_newline "[K8s Entrypoint MySQLd] Ignoring $f" ;;
    esac
done

#########################
### STOP LOCAL MYSQLD ###
#########################

# When using a local socket, mysqladmin shutdown will only complete when the
# server is actually down.
echo_newline '[entrypoints/mysqld_init_db.sh] Shutting down MySQLd via mysqladmin...'
mysqladmin -uroot --password="$MYSQL_ROOT_PASSWORD" shutdown --socket="$SOCKET"
echo_newline "[entrypoints/mysqld_init_db.sh] Successfully shut down MySQLd"
