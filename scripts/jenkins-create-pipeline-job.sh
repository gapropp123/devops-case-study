#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
source .env
set +a

JOB_NAME="${JOB_NAME:-demo-app-pipeline}"
REPO_URL="${REPO_URL:-https://github.com/gapropp123/devops-case-study.git}"
BRANCH="${BRANCH:-main}"
SCRIPT_PATH="${SCRIPT_PATH:-Jenkinsfile}"

AUTH=(-u "${JENKINS_ADMIN_USER:-admin}:${JENKINS_ADMIN_PASSWORD}")
COOKIEJAR=$(mktemp)
trap 'rm -f "$COOKIEJAR"' EXIT

CRUMB=$(curl -s -c "$COOKIEJAR" "${AUTH[@]}" 'http://localhost:8080/crumbIssuer/api/json' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['crumbRequestField']+':'+d['crumb'])")

CONFIG=$(mktemp)
cat > "$CONFIG" <<EOF
<flow-definition plugin="workflow-job">
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${REPO_URL}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/${BRANCH}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>${SCRIPT_PATH}</scriptPath>
    <lightweight>false</lightweight>
  </definition>
</flow-definition>
EOF

if curl -s -o /dev/null -w '%{http_code}' -b "$COOKIEJAR" "${AUTH[@]}" "http://localhost:8080/job/${JOB_NAME}/api/json" | grep -q 200; then
  echo "job exists, updating"
  curl -s -b "$COOKIEJAR" "${AUTH[@]}" -H "$CRUMB" -H "Content-Type: application/xml" \
    --data-binary @"$CONFIG" "http://localhost:8080/job/${JOB_NAME}/config.xml" \
    -o /dev/null -w 'update HTTP=%{http_code}\n'
else
  echo "creating job"
  curl -s -b "$COOKIEJAR" "${AUTH[@]}" -H "$CRUMB" -H "Content-Type: application/xml" \
    --data-binary @"$CONFIG" "http://localhost:8080/createItem?name=${JOB_NAME}" \
    -o /dev/null -w 'create HTTP=%{http_code}\n'
fi
rm -f "$CONFIG"
