#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
source .env
set +a

JOB_NAME="${JOB_NAME:-demo-app-pipeline}"
AUTH=(-u "${JENKINS_ADMIN_USER:-admin}:${JENKINS_ADMIN_PASSWORD}")
COOKIEJAR=$(mktemp)
trap 'rm -f "$COOKIEJAR"' EXIT

CRUMB=$(curl -s -c "$COOKIEJAR" "${AUTH[@]}" 'http://localhost:8080/crumbIssuer/api/json' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['crumbRequestField']+':'+d['crumb'])")

BEFORE=$(curl -s -b "$COOKIEJAR" "${AUTH[@]}" "http://localhost:8080/job/${JOB_NAME}/api/json" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('lastBuild',{}).get('number',0))")

echo "triggering ${JOB_NAME} (last build was #${BEFORE})..."
curl -s -b "$COOKIEJAR" "${AUTH[@]}" -H "$CRUMB" -X POST "http://localhost:8080/job/${JOB_NAME}/build" \
  -o /dev/null -w 'trigger HTTP=%{http_code}\n'

echo "waiting for a new build to start..."
for _ in $(seq 1 30); do
  NUM=$(curl -s -b "$COOKIEJAR" "${AUTH[@]}" "http://localhost:8080/job/${JOB_NAME}/api/json" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('lastBuild',{}).get('number',0))")
  [ "$NUM" -gt "$BEFORE" ] && break
  sleep 2
done
if [ "$NUM" -le "$BEFORE" ]; then
  echo "no new build appeared in time"
  exit 1
fi

echo "watching build #${NUM}..."
for _ in $(seq 1 60); do
  read -r RESULT BUILDING <<<"$(curl -s -b "$COOKIEJAR" "${AUTH[@]}" \
    "http://localhost:8080/job/${JOB_NAME}/${NUM}/api/json" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result') or 'null', d.get('building'))")"
  [ "$BUILDING" = "False" ] && break
  sleep 5
done

echo "build #${NUM}: ${RESULT}"
[ "$RESULT" = "SUCCESS" ]
