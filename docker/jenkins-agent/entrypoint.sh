#!/usr/bin/env bash
set -euo pipefail

SOCK=/var/run/docker.sock

if [ -S "$SOCK" ]; then
  SOCK_GID=$(stat -c '%g' "$SOCK")
  if ! getent group "$SOCK_GID" >/dev/null 2>&1; then
    groupadd -g "$SOCK_GID" docker-host
  fi
  GROUP_NAME=$(getent group "$SOCK_GID" | cut -d: -f1)
  usermod -aG "$GROUP_NAME" jenkins
fi

gosu jenkins git config --global --add safe.directory '*'

mkdir -p /home/jenkins/.m2
chown -R jenkins:jenkins /home/jenkins/.m2

exec gosu jenkins jenkins-agent "$@"
