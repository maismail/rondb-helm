#!/bin/bash

until nslookup $MGMD_HOSTNAME; do
    echo "Waiting for $MGMD_HOSTNAME to be resolvable..."
    sleep $(((RANDOM % 2) + 2))
done

until nslookup $MYSQLD_SERVICE_HOSTNAME; do
    echo "Waiting for $MYSQLD_SERVICE_HOSTNAME to be resolvable..."
    sleep $(((RANDOM % 2) + 2))
done

while true; do
    mysql \
        -h $MYSQLD_SERVICE_HOSTNAME \
        --protocol=tcp \
        --port=3306 \
        --user=$MYSQL_BENCH_USER \
        -p"$MYSQL_BENCH_PASSWORD" \
        -e "SELECT 1;"

    if [ $? -eq 0 ]; then
        echo "Successfully connected to MySQL server"
        break
    fi
    echo "MySQL query failed, retrying in a bit..."
    sleep 2
done
