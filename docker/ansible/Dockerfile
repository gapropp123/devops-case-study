FROM alpine/ansible:2.18.1

ARG KUBECTL_VERSION=v1.35.0

RUN apk add --no-cache py3-pip curl docker-cli docker-cli-compose gcompat libstdc++ \
    && pip3 install --break-system-packages --no-cache-dir kubernetes \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && curl -fsSL "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" -o /usr/local/bin/minikube \
    && chmod +x /usr/local/bin/minikube

WORKDIR /ansible
