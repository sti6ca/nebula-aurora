FROM docker:24.0.5-dind

ENV DEBIAN_FRONTEND=noninteractive

# Install utilities: bash, curl, ca-certificates, git, nginx, python3
RUN apk add --no-cache \
    curl \
    bash \
    kubectl \
    ca-certificates \
    python3 \
    py3-pip \
    nginx-openrc \
    openrc \
    sshpass \
    git

# install helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# install k3d (install script)
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# ensure /workspace will contain the bundle
WORKDIR /workspace

# Copy the bundle pieces into the image
COPY _wiki-service ./_wiki-service
COPY _wiki-chart ./_wiki-chart
COPY entrypoint.sh ./entrypoint.sh
COPY nginx.conf.template ./nginx.conf.template
COPY README.release.md ./README.release.md

RUN chmod +x /workspace/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/workspace/entrypoint.sh"]
