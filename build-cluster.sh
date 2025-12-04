#!/bin/bash

# Build script for the Docker-in-Docker cluster image

set -e

IMAGE_NAME="${1:-wiki-cluster}"
IMAGE_TAG="${2:-latest}"

echo "=========================================="
echo "Building Docker-in-Docker cluster image"
echo "=========================================="
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo ""

# Check if Dockerfile.cluster exists
if [ ! -f "Dockerfile.cluster" ]; then
  echo "✗ Dockerfile.cluster not found in current directory"
  echo "Run this script from the repository root"
  exit 1
fi

# Build the image
docker build \
  -f Dockerfile.cluster \
  -t "$IMAGE_NAME:$IMAGE_TAG" \
  -t "$IMAGE_NAME:latest" \
  .

echo ""
echo "=========================================="
echo "✓ Build complete!"
echo "=========================================="
echo ""
echo "Run the image with:"
echo ""
echo "Option 1: Docker Compose"
echo "  docker-compose -f docker-compose.cluster.yml up -d"
echo ""
echo "Option 2: Docker Run"
echo "  docker run -d --name wiki-cluster --privileged -p 8080:8080 $IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "Then test with:"
echo "  curl http://localhost:8080/users"
echo ""
