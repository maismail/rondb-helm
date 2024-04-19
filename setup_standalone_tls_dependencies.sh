#!/bin/bash

RONDB_NAMESPACE=$1

echo "Setting up dependencies for standalone RonDB deployment in namespace $RONDB_NAMESPACE"

# Note:
# This is not placed entirely in Helm dependencies because
#   1. Helm will not install the CRDs
#   2. We need to know the namespace to install the Ingress controller (see below)

# Deploy cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml

echo "Created cert-manager"

# The Ingress in the Helmchart requires the nginx Ingress controller
# to run (admission webhook).
# Setting TCP parameters since raw TCP connections are not supported by default;
#   see https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services/
#   These flags will create a ConfigMap with the TCP services and ports to expose.
# No need to also set RDRS HTTP (4406); can be defined in the actual Ingress.
helm upgrade --install rondb-ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace=$RONDB_NAMESPACE \
  --set "tcp.3306"="$RONDB_NAMESPACE/mysqld:3306" \
  --set "tcp.5406"="$RONDB_NAMESPACE/rdrs:5406"

echo "Created Nginx Ingress controller"

kubectl wait \
    --namespace $RONDB_NAMESPACE \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s

echo "Nginx Ingress controller is ready - we can instantiate nginx Ingress instances now"
