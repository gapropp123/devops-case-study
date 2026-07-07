#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

NS="default"
SA="jenkins-deployer"

kubectl apply -f k8s/rbac/ >/dev/null

echo "waiting for the service account token to populate..."
for _ in $(seq 1 30); do
  LEN=$(kubectl -n "$NS" get secret "${SA}-token" -o jsonpath='{.data.token}' 2>/dev/null | wc -c)
  [ "$LEN" -gt 100 ] && break
  sleep 1
done
if [ "$LEN" -le 100 ]; then
  echo "token did not populate in time"
  exit 1
fi

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl -n "$NS" get secret "${SA}-token" -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl -n "$NS" get secret "${SA}-token" -o jsonpath='{.data.token}' | base64 -d)

KUBECONFIG_FILE=$(mktemp)
trap 'rm -f "$KUBECONFIG_FILE"' EXIT

cat > "$KUBECONFIG_FILE" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: minikube
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA_DATA}
contexts:
  - name: jenkins-deployer@minikube
    context:
      cluster: minikube
      namespace: ${NS}
      user: jenkins-deployer
current-context: jenkins-deployer@minikube
users:
  - name: jenkins-deployer
    user:
      token: ${TOKEN}
EOF

B64=$(base64 -w0 "$KUBECONFIG_FILE")

if grep -q '^KUBECONFIG_DEPLOYER_B64=' .env; then
  sed -i "s|^KUBECONFIG_DEPLOYER_B64=.*|KUBECONFIG_DEPLOYER_B64=${B64}|" .env
else
  echo "KUBECONFIG_DEPLOYER_B64=${B64}" >> .env
fi

echo "done. KUBECONFIG_DEPLOYER_B64 written to .env (kubeconfig itself was not printed)."
