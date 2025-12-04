# Docker-in-Docker k3d Cluster Guide

This guide explains how to run the entire Kubernetes cluster (with the wiki-chart deployed) inside a Docker container using Docker-in-Docker (DinD) and k3d.

## Overview

The setup provides:
- **Docker-in-Docker**: Enables Docker operations within a containerized environment
- **k3d**: A lightweight Kubernetes distribution running inside Docker
- **Helm**: For deploying the wiki-chart
- **Port Forwarding**: Exposes FastAPI, Grafana, and Prometheus on port 8080 via Nginx proxy

## Prerequisites

- Docker installed and running on the host
- Docker Compose (optional, for easier management)
- ~4GB free RAM (k3d cluster requires resources)

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Build and start the containerized cluster
docker-compose -f docker-compose.cluster.yml up -d

# Check logs
docker-compose -f docker-compose.cluster.yml logs -f wiki-cluster

# Wait ~60-90 seconds for the cluster to fully initialize

# Test the API
curl http://localhost:8080/users
curl http://localhost:8080/metrics
curl http://localhost:8080/grafana

# Access in browser
# - FastAPI:    http://localhost:8080/
# - Grafana:    http://localhost:8080/grafana (login: admin/admin)
# - Prometheus: http://localhost:8080/prometheus
```

### Option 2: Using Docker Run with --privileged

```bash
# Build the image
docker build -f Dockerfile.cluster -t wiki-cluster:latest .

# Run the container
docker run -d \
  --name wiki-cluster \
  --privileged \
  -p 8080:8080 \
  -p 6443:6443 \
  -e DOCKER_TLS_CERTDIR= \
  wiki-cluster:latest

# Check logs (takes 60-90 seconds to initialize)
docker logs -f wiki-cluster

# Once ready, test the API
curl http://localhost:8080/users
```

## How It Works

### 1. Docker-in-Docker (DinD)
- The `Dockerfile.cluster` uses `docker:dind` as the base image
- This provides a Docker daemon running inside the container
- The `--privileged` flag allows the container to manage Docker operations

### 2. k3d Cluster Setup
- k3d is installed and used to create a lightweight Kubernetes cluster
- A single-node cluster named `wiki-cluster` is created
- Port 80 is mapped to the loadbalancer for HTTP traffic
- Port 8080 is reserved for the proxy/ingress layer

### 3. Helm Deployment
- The `wiki-chart` is deployed with:
  - PostgreSQL (via Bitnami subchart)
  - FastAPI service
  - Prometheus for metrics collection
  - Grafana for visualization
- All services use LoadBalancer type where applicable

### 4. Port Forwarding & Nginx Proxy
- `kubectl port-forward` is used internally to expose services:
  - FastAPI on port 8000 (internal)
  - Grafana on port 3000 (internal)
  - Prometheus on port 9090 (internal)
- Nginx acts as a reverse proxy on port 8080, routing traffic:
  - `/users`, `/posts`, `/user/*` → FastAPI
  - `/metrics` → FastAPI Prometheus endpoint
  - `/grafana/*` → Grafana
  - `/prometheus/*` → Prometheus
  - `/` → FastAPI (default)

## Exposed Endpoints

When the cluster is running, access the following on `http://localhost:8080`:

| Endpoint | Purpose |
|----------|---------|
| `/users` | POST/GET users (FastAPI) |
| `/posts` | POST/GET posts (FastAPI) |
| `/user/{id}` | GET specific user (FastAPI) |
| `/posts/{id}` | GET specific post (FastAPI) |
| `/metrics` | Prometheus metrics from FastAPI |
| `/grafana/...` | Grafana dashboard (login: admin/admin) |
| `/grafana/d/creation-dashboard-678/creation` | User/Post creation dashboard |
| `/prometheus` | Prometheus UI for metrics queries |

## Testing the API

### Test with curl

```bash
# Create a user
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'

# Create a post
curl -X POST http://localhost:8080/posts \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "content": "Hello from Docker!"}'

# Get a user
curl http://localhost:8080/user/1

# Get metrics
curl http://localhost:8080/metrics
```

### Test with the test script

```bash
# From inside the container (via docker exec)
docker exec wiki-cluster bash -c \
  'sed "s|BASE_URL=\"http://localhost:8080\"|BASE_URL=\"http://127.0.0.1:8000\"|" /opt/wiki-service/test_api.sh | bash'
```

## Container Management

### Check cluster status

```bash
# Using docker-compose
docker-compose -f docker-compose.cluster.yml ps

# Using docker run
docker ps | grep wiki-cluster
```

### View logs

```bash
# Using docker-compose
docker-compose -f docker-compose.cluster.yml logs -f wiki-cluster

# Using docker run
docker logs -f wiki-cluster
```

### Execute commands inside container

```bash
# Access kubectl inside the container
docker exec -it wiki-cluster kubectl get pods

# Check Helm releases
docker exec -it wiki-cluster helm list

# Get cluster info
docker exec -it wiki-cluster kubectl cluster-info
```

### Stop and remove the cluster

```bash
# Using docker-compose
docker-compose -f docker-compose.cluster.yml down

# Using docker run
docker stop wiki-cluster
docker rm wiki-cluster

# Clean up volumes (if needed)
docker volume prune
```

## Troubleshooting

### Cluster initialization timeout

If the cluster takes longer than expected to start:

```bash
# Check logs for errors
docker logs wiki-cluster

# Manually check cluster status
docker exec wiki-cluster kubectl cluster-info

# View pod status
docker exec wiki-cluster kubectl get pods --all-namespaces
```

### Port 8080 already in use

If port 8080 is already in use on your host:

```bash
# Using docker-compose, modify the port mapping in docker-compose.cluster.yml:
# ports:
#   - "9000:8080"  # Access via http://localhost:9000 instead

# Using docker run, change the port:
docker run -p 9000:8080 ...
```

### API requests failing

If API requests return connection refused:

1. Wait for the cluster to fully initialize (60-90 seconds)
2. Check Nginx logs inside the container:
   ```bash
   docker exec wiki-cluster cat /var/log/nginx/error.log
   ```
3. Verify FastAPI pod is running:
   ```bash
   docker exec wiki-cluster kubectl get pods -l app.kubernetes.io/component=wiki-fastapi
   ```

### Docker daemon issues

If you see "cannot connect to Docker daemon":

```bash
# Check if the container is still running
docker ps | grep wiki-cluster

# Restart the container
docker restart wiki-cluster
```

## Performance Considerations

- **Memory**: The k3d cluster + services typically requires 2-3GB RAM
- **Disk**: Plan for ~10GB of disk space for images and volumes
- **CPU**: At least 2 CPU cores recommended
- **Network**: Initial setup downloads container images (~1-2GB)

## File Structure

```
.
├── Dockerfile.cluster          # DinD + k3d + tools image
├── entrypoint-cluster.sh       # Initialization script
├── docker-compose.cluster.yml  # Docker Compose configuration
├── wiki-chart/                 # Helm chart (copied into image)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── wiki-service/               # FastAPI app (copied into image)
    └── ...
```

## Environment Variables

The container uses the following environment variables:

- `DOCKER_TLS_CERTDIR`: Set to empty to disable TLS (required for DinD)
- `DATABASE_URL`: Set within FastAPI deployment (PostgreSQL)

## Next Steps

1. **Production Deployment**: Consider using k3s on a VM instead of DinD for production
2. **Image Registry**: Push the built image to a container registry for easy distribution
3. **Helm Customization**: Modify `values.yaml` in the chart for production configs
4. **Monitoring**: Enhance Grafana dashboards for production metrics
5. **Persistence**: Use external storage backends for persistent volumes

## Support & References

- [k3d Documentation](https://k3d.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Docker-in-Docker Guide](https://docs.docker.com/engine/docker-overview/#docker-engine)
- [Bitnami PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
