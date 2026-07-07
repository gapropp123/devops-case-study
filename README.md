# DevOps Case Study

A small demo project. A Spring Boot service is built, tested, containerized and deployed to
Kubernetes (minikube) through a Jenkins pipeline running in Docker.

## Status

Work in progress.

## Layout

- `app/` – Spring Boot application
- `docker/` – Dockerfiles and Jenkins images
- `k8s/` – Kubernetes manifests
- `scripts/` – helper scripts

## Running locally

Requirements: Docker, and a running minikube.

More details will be added as the pieces come together (Jenkins + agent + app via
`docker compose`, then deploy to minikube).
