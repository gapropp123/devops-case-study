# DevOps Case Study

A small Spring Boot service that gets built, tested, containerized, pushed to a registry and
deployed to Kubernetes (minikube) through a Jenkins pipeline. Everything below runs on a single
machine with Docker and minikube - no cloud account needed except a container registry (GHCR by
default).

## Layout

- `app/` - the Spring Boot demo app (Maven, Java 21)
- `docker/` - Dockerfiles (app image, Jenkins controller, Jenkins agent, an Ansible runner image)
- `k8s/` - plain Kubernetes manifests (namespace, deployment, service, configmap, RBAC)
- `ansible/` - IaC playbooks that apply those manifests per environment (dev/staging/prod)
- `monitoring/` - Prometheus + Grafana, run separately from the cluster (see below for why)
- `ci/jcasc/` - Jenkins Configuration as Code
- `scripts/` - bootstrap/helper scripts used by the README steps and by `ansible/bootstrap-all.yml`
- `report/` - the write-up: `Part1_TheoreticalExercise_Report_DanhVo.md` and
  `Part2_PracticalExercise_Report_DanhVo.md`
- `Jenkinsfile` - the pipeline itself
- `Makefile` - thin wrapper around the Ansible playbooks

## Quick start (automated)

`make bootstrap-all` runs the whole thing end to end: starts minikube itself if no cluster is
running yet (with `metrics-server` enabled), brings up Jenkins + the monitoring stack, bootstraps
RBAC/secrets, creates the pipeline job, and triggers one real build that deploys the app - see
`ansible/bootstrap-all.yml`. If you don't have `make`, the Makefile's `bootstrap-all` target is a
single `docker run` you can copy directly; the steps below are the same thing done by hand, useful
if you want to understand or demo each piece individually.

## Prerequisites

- Docker + Docker Compose
- minikube - either already running (`minikube start`, then
  `minikube addons enable metrics-server` for `kubectl top`/Task 3), or let `make bootstrap-all`
  above start it for you
- A GHCR (or other registry) account + a personal access token with `write:packages` scope, if you
  want the pipeline to actually push images. The package this repo pushes to is private, so
  pulling it also needs credentials (see the imagePullSecret step below).

**If you're running this under your own GHCR account** (i.e. you're not pushing to the same
namespace this repo was developed under), change `REGISTRY` at the top of the `Jenkinsfile`
(`ghcr.io/<your-username>`) first - it's hardcoded, so a push with someone else's PAT against the
original owner's namespace will just fail with a permission error rather than silently doing the
wrong thing.

minikube's default runtime here is **containerd**, not Docker, so `eval $(minikube docker-env)`
won't make locally-built images visible to the cluster. Images reach the cluster either via
`minikube image load <tag>` (for a quick manual test) or by being pulled from the registry (what
the pipeline does).

## 1. Set up secrets

```bash
cp .env.example .env
# edit .env: set JENKINS_ADMIN_PASSWORD, GHCR_USERNAME/GHCR_PAT, GRAFANA_ADMIN_PASSWORD
```

`.env` is gitignored. Nothing in it is baked into an image or committed anywhere.

## 2. Start Jenkins (controller + agent) and the demo app container

```bash
./scripts/jenkins-bootstrap.sh
```

This builds and starts the controller, waits for it to come up, pulls the one-time agent secret
Jenkins generates for `agent-1` out of the running controller (can't be known ahead of time), and
then starts the agent with it. It also starts a standalone `demo-app` container on port 8081 as a
quick non-Kubernetes smoke path (`curl localhost:8081/version`).

Check `http://localhost:8080` (login with the admin user/password from `.env`) → **Manage
Jenkins → Nodes** and confirm `agent-1` shows Online. The controller itself runs with
`numExecutors: 0` (set in `ci/jcasc/jenkins.yaml`), so no build can ever land on it by accident -
only the agent runs builds.

## 3. Bootstrap the Kubernetes side

```bash
kubectl apply -f k8s/rbac/          # jenkins-deployer ServiceAccount + least-privilege Role
./scripts/gen-deployer-kubeconfig.sh   # builds a self-contained kubeconfig for that SA, writes it (base64) into .env
./scripts/gen-ghcr-pull-secret.sh      # imagePullSecret so the cluster can pull the private image
```

The default minikube kubeconfig points at client-cert *files* that don't exist inside the Jenkins
agent container, so the pipeline instead uses a dedicated ServiceAccount token embedded directly
in a kubeconfig (no file paths, just the token + the cluster CA data). `gen-deployer-kubeconfig.sh`
writes that into `.env` as `KUBECONFIG_DEPLOYER_B64`; JCasC turns it into a Jenkins "Secret file"
credential the pipeline's Deploy stage uses.

Restart the controller once after this so JCasC picks up the new credential:

```bash
docker compose up -d --build jenkins
```

## 4. Create the pipeline job

```bash
REPO_URL=/workspace-src ./scripts/jenkins-create-pipeline-job.sh
```

`/workspace-src` is the repo bind-mounted read-only into both the controller and the agent - it
lets the pipeline build straight from your working tree without pushing every change first. Point
`REPO_URL` at this repo's GitHub URL instead if you want the job to build from GitHub the way a
real setup would.

Trigger a build from the Jenkins UI, or:

```bash
curl -u "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_PASSWORD" -X POST http://localhost:8080/job/demo-app-pipeline/build
```

The pipeline: `Checkout → Compile → Test & Quality (parallel: Unit Test + Code Quality) → Package
→ Docker Build → Container Validation → Push → Deploy → Rollout Verify & Smoke Test`. It packages
the JAR once and the runtime image just `COPY`s it in - no second `mvn` run inside the Docker
build. On a deploy that comes up unhealthy (bad readiness, unschedulable, or a failed smoke check)
it collects diagnostics, rolls the deployment back automatically, and still fails the build - a
successful rollback is not treated as a successful deploy.

## 5. Check the app

```bash
curl http://$(minikube ip):30080/version
curl http://$(minikube ip):30080/actuator/health
kubectl get pods
```

Everything runs in the `default` namespace on purpose, so there's no `-n <namespace>` to remember for
day-to-day `kubectl` commands (the per-environment Ansible stack in section 7 is the exception - those
get their own namespace each, since the whole point there is environment separation).

`/version` returns the Git commit the running image was built from, which is how rollouts and
rollbacks get verified in this project (by SHA, not by eyeballing revision numbers).

## 6. Monitoring (optional but recommended)

```bash
./scripts/gen-prometheus-secrets.sh
docker compose -f monitoring/docker-compose.yml --env-file .env up -d
```

Runs on the host, next to the cluster rather than inside it, so it doesn't compete with
minikube's small resource budget. Prometheus (`localhost:9090`) scrapes the app's
`/actuator/prometheus` and Jenkins' own Prometheus plugin endpoint; Grafana (`localhost:3000`,
login from `.env`) comes with both dashboards pre-provisioned. Alert rules live in
`monitoring/alerts.yml` (app down, high error rate, high latency).

Must be run with `--env-file .env` from the repo root - Compose only auto-reads `.env` from the
directory it's invoked in, and this stack's compose file lives in `monitoring/`.

## 7. IaC across environments (Task 2)

```bash
make bootstrap-all ENV=dev       # or ENV=staging / ENV=prod
make teardown-all ENV=dev        # tears down that namespace too (plus the core stack, as always)
```

`ENV=` is additive on top of `bootstrap-all`'s core stack (cluster + Jenkins + monitoring +
pipeline deploy to `default`) - it builds `demo-app:v1` from whatever's in `app/target/demo-app.jar`,
`minikube image load`s it, then applies that environment's namespace/configmap/deployment/service
via the `k8s-app` Ansible role, entirely independent of the Jenkins pipeline. Each environment is
its own namespace (`demo-dev`, `demo-staging`, `demo-prod`) with its own replica count and resource
limits (`ansible/group_vars/*.yml`). Re-running with the same `ENV=` after nothing has changed
reports `changed=0` on the `k8s-app` tasks - idempotent, not just re-runnable. `make` isn't
required; both targets are a thin wrapper around a `docker run` of the `docker/ansible` image, so
you can run the underlying Ansible command directly if you don't have `make` installed (see the
`Makefile` for the exact command).

## Troubleshooting

- **Agent shows offline**: check `docker compose logs jenkins-agent`. Usually means
  `JENKINS_AGENT_SECRET` in `.env` is stale - re-run `scripts/jenkins-bootstrap.sh`.
- **`docker.sock: permission denied` in the agent**: the agent image adds its build user to a
  group matching the host's docker socket GID; if that GID differs on your machine, rebuild the
  agent image (`docker compose build jenkins-agent`).
- **Deploy stage can't reach the cluster**: confirm the agent container is on the external
  `minikube` Docker network (`docker network inspect minikube`), and that
  `KUBECONFIG_DEPLOYER_B64` in `.env` isn't empty.
- **`ImagePullBackOff`**: the GHCR package is private - confirm `ghcr-pull-secret` exists
  (`kubectl get secret ghcr-pull-secret`) and re-run `scripts/gen-ghcr-pull-secret.sh` if the PAT
  rotated.
- **Prometheus shows the `demo-app` target down**: it scrapes `$(minikube ip):30080` directly, so
  if minikube's IP changed (e.g. after a restart) update the target in `monitoring/prometheus.yml`
  and restart the `prometheus` container.
