#!/bin/bash
set -e

echo "=========================================="
echo "Starting Docker-in-Docker cluster setup"
echo "=========================================="

# Start Docker daemon in background
echo "Starting Docker daemon..."
dockerd &
DOCKER_PID=$!

# Wait for Docker to be ready
echo "Waiting for Docker daemon to be ready..."
for i in {1..30}; do
  if docker ps &>/dev/null; then
    echo "✓ Docker daemon is ready"
    break
  fi
  echo "Attempt $i/30: Waiting for Docker..."
  sleep 2
done

# Verify Docker is running
if ! docker ps &>/dev/null; then
  echo "✗ Docker daemon failed to start"
  kill $DOCKER_PID 2>/dev/null || true
  exit 1
fi

echo ""
echo "=========================================="
echo "Creating k3d cluster"
echo "=========================================="

# Create k3d cluster with proper configuration
# - Single server node (no agents for simplicity)
# - Port 80 for HTTP (internal, mapped to 8080 externally)
# - Port 6443 for Kubernetes API
k3d cluster create wiki-cluster \
  --servers 1 \
  --agents 0 \
  --port 80:80@loadbalancer \
  --port 8080:8080@loadbalancer \
  --wait

echo "✓ k3d cluster 'wiki-cluster' created"

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
for i in {1..30}; do
  if kubectl cluster-info &>/dev/null; then
    echo "✓ Kubernetes cluster is ready"
    break
  fi
  echo "Attempt $i/30: Waiting for cluster..."
  sleep 2
done

echo ""
echo "=========================================="
echo "Deploying Helm chart"
echo "=========================================="

# Add Bitnami Helm repo for PostgreSQL chart
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deploy the wiki chart
echo "Installing wiki chart..."
helm install wiki /opt/wiki-chart \
  --set fastapi.image_name=tatosbeer/wiki:latest \
  --set fastapi.service.type=LoadBalancer \
  --set fastapi.service.port=8080 \
  --set postgresql.auth.username=postgres \
  --set postgresql.auth.password=postgres \
  --set postgresql.auth.database=nebula \
  --wait \
  --timeout 5m || {
    echo "✗ Helm install failed, but continuing..."
    helm list
    kubectl get pods
  }

echo "✓ Wiki chart deployment initiated"

echo ""
echo "=========================================="
echo "Waiting for pods to be ready"
echo "=========================================="

# Wait for FastAPI pod to be ready
for i in {1..60}; do
  READY=$(kubectl get pods -l app.kubernetes.io/component=wiki-fastapi -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
  if [ "$READY" = "True" ]; then
    echo "✓ FastAPI pod is ready"
    break
  fi
  echo "Attempt $i/60: FastAPI pod not ready (status: $READY)..."
  sleep 2
done

echo ""
echo "=========================================="
echo "Setting up port forwarding"
echo "=========================================="

# Get the FastAPI service
FASTAPI_POD=$(kubectl get pods -l app.kubernetes.io/component=wiki-fastapi -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$FASTAPI_POD" ]; then
  echo "⚠ FastAPI pod not found, skipping port forward"
else
  echo "FastAPI pod: $FASTAPI_POD"
  
  # Port forward FastAPI to 8000 (internal)
  kubectl port-forward "pod/$FASTAPI_POD" 8000:8000 &
  PF_PID=$!
  echo "✓ Port-forward started (PID: $PF_PID)"
fi

# Port forward Grafana to 3000 (internal)
GRAFANA_POD=$(kubectl get pods -l app.kubernetes.io/component=wiki-grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_POD" ]; then
  kubectl port-forward "pod/$GRAFANA_POD" 3000:3000 &
  echo "✓ Grafana port-forward started"
fi

# Port forward Prometheus to 9090 (internal)
PROMETHEUS_POD=$(kubectl get pods -l app.kubernetes.io/component=wiki-prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PROMETHEUS_POD" ]; then
  kubectl port-forward "pod/$PROMETHEUS_POD" 9090:9090 &
  echo "✓ Prometheus port-forward started"
fi

echo ""
echo "=========================================="
echo "Setting up nginx ingress proxy on port 8080"
echo "=========================================="

# Create a simple nginx config to route requests
cat > /tmp/nginx.conf <<'NGINX_EOF'
upstream fastapi {
  server localhost:8000;
}

upstream grafana {
  server localhost:3000;
}

upstream prometheus {
  server localhost:9090;
}

server {
  listen 8080;
  server_name _;

  # FastAPI endpoints
  location /users {
    proxy_pass http://fastapi;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  location /posts {
    proxy_pass http://fastapi;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  location /user {
    proxy_pass http://fastapi;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  location /metrics {
    proxy_pass http://fastapi;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  # Grafana
  location /grafana {
    proxy_pass http://grafana/grafana;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  # Prometheus
  location /prometheus {
    proxy_pass http://prometheus;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  # Root - FastAPI
  location / {
    proxy_pass http://fastapi;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
NGINX_EOF

# Install and start nginx
apk add --no-cache nginx
mkdir -p /var/run/nginx
nginx -c /tmp/nginx.conf

echo "✓ Nginx proxy started on port 8080"

echo ""
echo "=========================================="
echo "Cluster is ready!"
echo "=========================================="
echo ""
echo "Exposed endpoints (via port 8080):"
echo "  - FastAPI API:  http://localhost:8080/users, /posts/, /user/{id}"
echo "  - Metrics:      http://localhost:8080/metrics"
echo "  - Grafana:      http://localhost:8080/grafana/d/creation-dashboard-678/creation"
echo "  - Prometheus:   http://localhost:8080/prometheus"
echo ""
echo "To keep the container running, sleeping indefinitely..."
echo "=========================================="

# Keep container running
tail -f /dev/null
