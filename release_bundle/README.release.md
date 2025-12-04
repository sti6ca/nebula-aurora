# Release bundle for running cluster inside a container (DinD + k3d)

This bundle contains the project files and a Dockerfile to run a full k3d cluster inside a container.

Structure:

/
| _wiki-service/
| _wiki-chart/
| Dockerfile
| entrypoint.sh
| nginx.conf.template

Build and run (requires privileged mode to run Docker-in-Docker):

```bash
# From repository root (where `release_bundle` directory is located)
docker build -t nebula-release:latest -f release_bundle/Dockerfile .

# Run privileged so that DinD can start. Map host port 8080 to container 8080.
docker run --privileged -p 8080:8080 --rm -it nebula-release:latest
```

After startup, the container will:

- start Docker-in-Docker
- create a k3d cluster
- build and load the `local/wiki:latest` image into the cluster
- install the Helm chart from `_wiki-chart` with `fastapi.image_name=local/wiki:latest`
- port-forward services into the container and run nginx to expose them on container port 8080
