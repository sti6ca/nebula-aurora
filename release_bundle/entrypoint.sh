#!/usr/bin/env bash
set -euo pipefail

ROOT="/workspace"

log() { echo "[entrypoint] $*"; }

export PATH="/usr/local/bin:$PATH"

# Start Docker daemon (dind)
log "Starting dockerd..."
dockerd-entrypoint.sh &

# Wait for docker to be ready
for i in {1..60}; do
  if docker info >/dev/null 2>&1; then
    log "Docker is ready"
    break
  fi
  sleep 1
done

# Create k3d cluster
CLUSTER_NAME="nebula"
if ! k3d cluster list | grep -q " ${CLUSTER_NAME} "; then
  log "Creating k3d cluster '${CLUSTER_NAME}'"
  k3d cluster create ${CLUSTER_NAME} --wait
else
  log "k3d cluster '${CLUSTER_NAME}' already exists"
fi

# Build the FastAPI image inside DinD and load into k3d
log "Building FastAPI image"
docker build -t local/wiki:latest ${ROOT}/_wiki-service
log "Loading image into k3d cluster"
k3d image import local/wiki:latest --cluster ${CLUSTER_NAME} || k3d image import local/wiki:latest

# Deploy helm chart
RELEASE_NAME="wiki"
log "Installing Helm chart"
helm upgrade --install ${RELEASE_NAME} ${ROOT}/_wiki-chart --wait --timeout 5m --set fastapi.image_name=local/wiki:latest

# Start kubectl port-forwards to container-local ports
log "Starting port-forwards"
kubectl port-forward svc/${RELEASE_NAME}-fastapi 8000:8000 >/tmp/port-forward-fastapi.log 2>&1 &
PF_FASTAPI_PID=$!
kubectl port-forward svc/${RELEASE_NAME}-grafana 3000:3000 >/tmp/port-forward-grafana.log 2>&1 &
PF_GRAFANA_PID=$!
kubectl port-forward svc/${RELEASE_NAME}-prometheus 9090:9090 >/tmp/port-forward-prom.log 2>&1 &
PF_PROM_PID=$!

log "Waiting for services to be reachable on localhost"
for i in {1..60}; do
  if curl -sSf http://127.0.0.1:8000/ >/dev/null 2>&1; then
    log "FastAPI is reachable"
    break
  fi
  sleep 2
done

# Render nginx config and start nginx to expose all endpoints through port 8080
NGINX_CONF_PATH=/etc/nginx/nginx.conf
log "Writing nginx config to ${NGINX_CONF_PATH}"
cat ${ROOT}/nginx.conf.template > ${NGINX_CONF_PATH}

log "Starting nginx"
nginx -g 'daemon off;'

# On exit, cleanup background processes
trap 'log "Shutting down..."; kill ${PF_FASTAPI_PID} ${PF_GRAFANA_PID} ${PF_PROM_PID} || true; k3d cluster delete ${CLUSTER_NAME} || true; exit' SIGINT SIGTERM

wait
