#!/usr/bin/env bash
set -euo pipefail

mkdir -p /run/sshd /home/soma/.ssh /shared
chown -R soma:soma /home/soma/.ssh
chmod 700 /home/soma/.ssh

if [ -f /shared/id_ed25519.pub ]; then
    cp /shared/id_ed25519.pub /home/soma/.ssh/authorized_keys
    chown soma:soma /home/soma/.ssh/authorized_keys
    chmod 600 /home/soma/.ssh/authorized_keys
fi

ssh-keygen -A
exec /usr/sbin/sshd -D -e
