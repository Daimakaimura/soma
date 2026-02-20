#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

cleanup() {
    docker compose down -v --remove-orphans >/dev/null 2>&1 || true
}

trap cleanup EXIT
cleanup

docker compose up -d --build body controller

docker compose exec -T controller bash -lc '
set -euo pipefail
mkdir -p /shared /root/.ssh
if [ ! -f /shared/id_ed25519 ]; then
    ssh-keygen -q -t ed25519 -N "" -f /shared/id_ed25519
fi
cat > /root/.ssh/config <<'"'"'EOF'"'"'
Host body
  HostName body
  User soma
  IdentityFile /shared/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  UserKnownHostsFile /root/.ssh/known_hosts
  ConnectTimeout 5
EOF
chmod 600 /root/.ssh/config
'

docker compose exec -T body bash -lc '
set -euo pipefail
install -d -m 700 -o soma -g soma /home/soma/.ssh
cat /shared/id_ed25519.pub > /home/soma/.ssh/authorized_keys
chown soma:soma /home/soma/.ssh/authorized_keys
chmod 600 /home/soma/.ssh/authorized_keys
'

docker compose exec -T controller bash -lc '
set -euo pipefail
for _ in $(seq 1 30); do
    if ssh body "echo ssh-ok" >/dev/null 2>&1; then
        exit 0
    fi
    sleep 1
done
echo "ssh to body failed" >&2
exit 1
'

docker compose exec -T controller bash -lc '/workspace/tests/docker/run-in-container.sh /workspace'
echo "Docker smoke tests passed."
