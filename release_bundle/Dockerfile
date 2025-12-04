FROM docker:24.0.5-dind

ENV DEBIAN_FRONTEND=noninteractive

# Install utilities: bash, curl, ca-certificates, git, nginx, python3
RUN apk add --no-cache curl bash ca-certificates py3-pip nginx-openrc openrc sshpass git \
  || true

# install kubectl
RUN set -eux; \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; \
    rm -f kubectl

# install helm
RUN set -eux; \
    curl -fsSL https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz -o /tmp/helm.tgz; \
    tar -zxvf /tmp/helm.tgz -C /tmp; \
    install -o root -g root -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm; \
    rm -rf /tmp/helm.tgz /tmp/linux-amd64

# install k3d (install script)
RUN set -eux; \
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
