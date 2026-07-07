#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
source .env
set +a

mkdir -p monitoring/secrets
printf '%s' "${JENKINS_ADMIN_PASSWORD}" > monitoring/secrets/jenkins_password
echo "done."
