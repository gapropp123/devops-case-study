#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
source .env
set +a

NS="default"
SECRET_NAME="ghcr-pull-secret"

kubectl create secret docker-registry "$SECRET_NAME" \
  --namespace "$NS" \
  --docker-server=ghcr.io \
  --docker-username="${GHCR_USERNAME}" \
  --docker-password="${GHCR_PAT}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "done."
