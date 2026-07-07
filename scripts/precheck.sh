#!/usr/bin/env bash
set -uo pipefail

missing=0

if [[ "$(uname -s)" == "Darwin" ]]; then
  os_id="macos"
elif [[ -f /etc/os-release ]]; then
  os_id="$(. /etc/os-release && echo "$ID")"
else
  os_id="unknown"
fi

echo "== detected OS: ${os_id} =="

suggest() {
  local tool="$1"
  case "$os_id" in
    ubuntu|debian)
      case "$tool" in
        docker)
          echo "    sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin"
          ;;
        minikube)
          echo "    curl -Lo /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install /tmp/minikube /usr/local/bin/minikube"
          ;;
        kubectl)
          echo "    curl -LO \"https://dl.k8s.io/release/\$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\" && sudo install -m0755 kubectl /usr/local/bin/kubectl"
          ;;
      esac
      ;;
    fedora|rhel|centos)
      case "$tool" in
        docker)
          echo "    sudo dnf install -y docker docker-compose-plugin"
          ;;
        minikube)
          echo "    sudo dnf install -y https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm"
          ;;
        kubectl)
          echo "    sudo dnf install -y kubectl"
          ;;
      esac
      ;;
    arch)
      case "$tool" in
        docker)
          echo "    sudo pacman -S --noconfirm docker docker-compose"
          ;;
        minikube)
          echo "    sudo pacman -S --noconfirm minikube"
          ;;
        kubectl)
          echo "    sudo pacman -S --noconfirm kubectl"
          ;;
      esac
      ;;
    macos)
      case "$tool" in
        docker)
          echo "    brew install --cask docker   # Docker Desktop; includes the compose plugin"
          ;;
        minikube)
          echo "    brew install minikube"
          ;;
        kubectl)
          echo "    brew install kubectl"
          ;;
      esac
      ;;
    *)
      case "$tool" in
        docker)
          echo "    see https://docs.docker.com/engine/install/"
          ;;
        minikube)
          echo "    see https://minikube.sigs.k8s.io/docs/start/"
          ;;
        kubectl)
          echo "    see https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
          ;;
      esac
      ;;
  esac
}

check_cmd() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    echo "[ok]      $tool ($(command -v "$tool"))"
  else
    echo "[missing] $tool"
    suggest "$tool"
    missing=1
  fi
}

check_cmd docker
check_cmd minikube
check_cmd kubectl

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    echo "[ok]      docker compose plugin"
  else
    echo "[missing] docker compose plugin"
    suggest docker
    missing=1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "[warn]    docker CLI found but the daemon isn't reachable - is it running, and"
    echo "          is your user in the 'docker' group? (sudo usermod -aG docker \$USER, then log out/in)"
    missing=1
  fi
fi

echo
if [ "$missing" -ne 0 ]; then
  echo "precheck failed - install/fix what's flagged above, then re-run."
  exit 1
fi
echo "precheck passed - docker, docker compose, minikube and kubectl are all available."
