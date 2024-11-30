#!/bin/bash

set -e

{{ include "rondb.sedMyCnfFile" . }}

{{ include "rondb.initializeMySQLd" . }}

###############################
# CHECK OUR DNS IS RESOLVABLE #
###############################

# We need this, otherwise the MGMd will not recognise our IP address
# when we try to connect at startup.

OWN_HOSTNAME="{{ $.Values.meta.mysqld.statefulSet.name }}-$MYSQLD_NR.{{ $.Values.meta.mysqld.headlessClusterIp.name }}.{{ $.Release.Namespace }}.svc.cluster.local"
until nslookup $OWN_HOSTNAME; do
    echo "[K8s Entrypoint MySQLd] Waiting for $OWN_HOSTNAME to be resolvable..."
    sleep $(((RANDOM % 2) + 2))
done

echo "[K8s Entrypoint MySQLd] $OWN_HOSTNAME is resolvable..."
