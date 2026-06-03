FROM myoung34/github-runner:latest

ARG TERRAFORM_VERSION=1.15.5
ARG KUBECTL_VERSION=1.35.5
ARG HELM_VERSION=3.15.4

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git jq \
  && rm -rf /var/lib/apt/lists/*

# Terraform
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/tf.zip \
  && unzip -q /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip

# kubectl
RUN curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  && chmod +x /usr/local/bin/kubectl

# helm
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" -o /tmp/helm.tgz \
  && tar -xzf /tmp/helm.tgz -C /tmp && install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm \
  && rm -rf /tmp/helm.tgz /tmp/linux-amd64
