#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] Starting Docker daemon (dockerd)..."
# Start dockerd (from docker:dind)
dockerd &

# Wait for Docker daemon to be ready
echo "[entrypoint] Waiting for Docker daemon to start..."
timeout=60
while ! docker info >/dev/null 2>&1; do
    if [ $timeout -le 0 ]; then
        echo "[entrypoint][ERROR] Docker daemon failed to start"
        exit 1
    fi
    sleep 1
    timeout=$((timeout - 1))
done
echo "[entrypoint] ✓ Docker daemon is ready"

# Build the FastAPI Docker image from the copied bundle
echo "[entrypoint] Building FastAPI Docker image..."
if [ -d "/workspace/_wiki-service" ]; then
    cd /workspace/_wiki-service
else
    echo "[entrypoint][ERROR] _wiki-service directory not found in /workspace"
    exit 1
fi

docker build -t wiki-service:local .
echo "[entrypoint] ✓ FastAPI image built successfully"

# Create k3d cluster
echo "[entrypoint] Creating k3d cluster 'wiki-cluster'..."
k3d cluster create wiki-cluster --wait --timeout 120s || true
echo "[entrypoint] ✓ k3d cluster create attempted"

# Import the Docker image into k3d (if cluster exists)
echo "[entrypoint] Importing Docker image into k3d..."
if k3d cluster list | grep -q "wiki-cluster"; then
    k3d image import wiki-service:local --cluster wiki-cluster || true
    echo "[entrypoint] ✓ Image imported into k3d"
else
    echo "[entrypoint][WARNING] k3d cluster not found; skipping image import"
fi

# Set kubeconfig for kubectl
echo "[entrypoint] Setting KUBECONFIG"
export KUBECONFIG=$(k3d kubeconfig write wiki-cluster)

# Remove common taints that could prevent scheduling (best-effort)
echo "[entrypoint] Removing node taints (best-effort)"
kubectl taint nodes --all node.kubernetes.io/disk-pressure- 2>/dev/null || true
kubectl taint nodes --all node.kubernetes.io/memory-pressure- 2>/dev/null || true
kubectl taint nodes --all node.kubernetes.io/network-unavailable- 2>/dev/null || true

# Deploy the Helm chart (install or upgrade)
echo "[entrypoint] Deploying Helm chart from /workspace/_wiki-chart"
cd /workspace/_wiki-chart
helm upgrade --install wiki . --set fastapi.image_name=wiki-service:local --wait --timeout 5m || true
echo "[entrypoint] ✓ Helm chart install/upgrade attempted"

# Wait for all pods in default namespace to be ready (best-effort)
echo "[entrypoint] Waiting for pods to be ready (this may take a couple minutes)"
kubectl wait --for=condition=ready pod --all --timeout=300s || {
    echo "[entrypoint][WARNING] kubectl wait timed out; listing pod statuses"
    kubectl get pods --all-namespaces
}

echo ""
echo "[entrypoint] Cluster status summary"
kubectl get pods --all-namespaces || true
kubectl get svc --all-namespaces || true
kubectl get ingress --all-namespaces || true

echo ""
echo "=========================================="
echo "Cluster setup attempted. Access endpoints via container's port 8080 (mapped by host):"
echo "  http://<host>:8080/"
echo "  http://<host>:8080/users"
echo "  http://<host>:8080/posts"
echo "  http://<host>:8080/grafana/d/creation-dashboard-678/creation"
echo "=========================================="

# Keep container running so evaluators can connect
tail -f /dev/null