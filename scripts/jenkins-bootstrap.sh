#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo ".env not found. Copy .env.example to .env and set JENKINS_ADMIN_PASSWORD first."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

echo "== building and starting the controller =="
docker compose up -d --build jenkins demo-app

echo "== waiting for Jenkins to come up =="
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/login || true)
  [ "$code" = "200" ] && break
  sleep 3
done
if [ "$code" != "200" ]; then
  echo "jenkins did not come up in time"
  exit 1
fi

echo "== fetching the agent-1 JNLP secret =="
COOKIEJAR=$(mktemp)
trap 'rm -f "$COOKIEJAR"' EXIT
AUTH=(-u "${JENKINS_ADMIN_USER:-admin}:${JENKINS_ADMIN_PASSWORD}")

CRUMB=$(curl -s -c "$COOKIEJAR" "${AUTH[@]}" 'http://localhost:8080/crumbIssuer/api/json' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['crumbRequestField']+':'+d['crumb'])")

SECRET=$(curl -s -b "$COOKIEJAR" "${AUTH[@]}" -H "$CRUMB" \
  --data-urlencode "script=println(jenkins.model.Jenkins.instance.getComputer('agent-1').getJnlpMac())" \
  http://localhost:8080/scriptText)

if ! [[ "$SECRET" =~ ^[0-9a-f]+$ ]]; then
  echo "could not fetch the agent secret (unexpected response)"
  exit 1
fi

sed -i "s/^JENKINS_AGENT_SECRET=.*/JENKINS_AGENT_SECRET=${SECRET}/" .env

export JENKINS_AGENT_SECRET="$SECRET"

echo "== starting the agent =="
docker compose up -d --build jenkins-agent

echo "done. check the Nodes page in Jenkins to confirm agent-1 is online."
