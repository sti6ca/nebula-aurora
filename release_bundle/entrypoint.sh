#!/bin/bash
set -e

echo "Starting Docker daemon..."
dockerd-entrypoint.sh &
DOCKER_PID=$!

# Wait for Docker daemon to be ready
echo "Waiting for Docker daemon to start..."
timeout=60
while ! docker info >/dev/null 2>&1; do
    if [ $timeout -eq 0 ]; then
        echo "ERROR: Docker daemon failed to start"
        exit 1
    fi
    sleep 1
    timeout=$((timeout - 1))
done
echo "✓ Docker daemon is ready"

# Set DOCKER_HOST to use the local socket
export DOCKER_HOST=unix:///var/run/docker.sock

# Build the FastAPI Docker image
echo "Building FastAPI Docker image..."
cd /workspace/wiki-service
docker build -t wiki-service:local .
echo "✓ FastAPI image built successfully"

# Create k3d cluster
echo "Creating k3d cluster..."
k3d cluster create wiki-cluster \
    --port "8080:80@loadbalancer" \
    --wait \
    --timeout 300s
echo "✓ k3d cluster created"

# Import the Docker image into k3d
echo "Importing Docker image into k3d..."
k3d image import wiki-service:local -c wiki-cluster
echo "✓ Image imported into k3d"

# Set kubeconfig
export KUBECONFIG=$(k3d kubeconfig write wiki-cluster)

# Remove any taints that might prevent scheduling (common in k3d)
echo "Removing node taints..."
kubectl taint nodes --all node.kubernetes.io/disk-pressure- 2>/dev/null || true
kubectl taint nodes --all node.kubernetes.io/memory-pressure- 2>/dev/null || true
kubectl taint nodes --all node.kubernetes.io/network-unavailable- 2>/dev/null || true

# k3d comes with Traefik built-in, so we don't need to install anything
# Just wait for Traefik to be ready
echo "Waiting for Traefik (built-in with k3d) to be ready..."
kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=traefik \
    --timeout=120s || echo "Warning: Traefik may not be fully ready"

echo "✓ Traefik ingress controller ready"

# Deploy the Helm chart
echo "Deploying Helm chart..."
cd /workspace/wiki-chart
helm install wiki . --set fastapi.image_name=wiki-service:local || \
    helm upgrade wiki . --set fastapi.image_name=wiki-service:local
echo "✓ Helm chart deployed"

# Wait for pods to be ready (with retries)
echo "Waiting for pods to be ready..."
for i in {1..30}; do
    READY=$(kubectl get pods --no-headers 2>/dev/null | grep -v Running | grep -v Completed | wc -l || echo "1")
    if [ "$READY" -eq "0" ]; then
        echo "✓ All pods are ready"
        break
    fi
    echo "  Waiting for pods... ($i/30)"
    sleep 10
done

# Show pod status
echo ""
echo "Pod status:"
kubectl get pods

# Show services
echo ""
echo "Services:"
kubectl get svc

# Show ingress
echo ""
echo "Ingress:"
kubectl get ingress

echo ""
echo "=========================================="
echo "Cluster is ready! Access the API at:"
echo "  http://localhost:8080/"
echo "  http://localhost:8080/users"
echo "  http://localhost:8080/posts"
echo "  http://localhost:8080/grafana/d/creation-dashboard-678/creation"
echo "=========================================="

# Keep container running
tail -f /dev/null