#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-/workspace}"
FAKEBIN="${REPO_ROOT}/tests/docker/fakebin"
export PATH="${FAKEBIN}:${PATH}"

run_suite() {
    local suite_name="$1"
    local soma_body="$2"
    local expected_host="$3"
    local workdir="/tmp/soma-${suite_name}"
    local today

    rm -rf "$workdir"
    mkdir -p "$workdir"
    tar -C "$REPO_ROOT" --exclude=.git -cf - . | tar -C "$workdir" -xf -

    cd "$workdir"

    cat > soma.env <<EOF
SOMA_AGENT=opencode
SOMA_MODEL=fake/model
SOMA_BIRTH_MODEL=fake/model
SOMA_AUTONOMY=suggest
SOMA_BODY=${soma_body}
EOF

    ./soma birth >/tmp/${suite_name}-birth.log 2>&1
    ./soma cycle >/tmp/${suite_name}-cycle.log 2>&1
    query_output="$(./soma query "status?" 2>/tmp/${suite_name}-query.log)"
    ./soma audit >/tmp/${suite_name}-audit.log 2>&1

    today="$(date -u +%Y-%m-%d)"

    test -s memory/self.md
    test -s memory/lessons.md
    test -x lib/sense.sh
    test -s "memory/journal/${today}.md"
    test -s run/heartbeat
    test -s "run/audit-${today}.md"

    if ! printf '%s\n' "$query_output" | grep -q "fake response"; then
        echo "query output did not contain fake response for ${suite_name}" >&2
        printf '%s\n' "$query_output" >&2
        exit 1
    fi

    latest_raw="$(ls -1 run/raw/*.txt | tail -n 1)"
    if ! grep -q "host_name: ${expected_host}" "$latest_raw"; then
        echo "unexpected host in ${latest_raw} for ${suite_name}" >&2
        cat "$latest_raw" >&2
        exit 1
    fi

    echo "[ok] ${suite_name}"
}

run_suite local local controller
run_suite ssh "ssh://body" body
echo "All smoke suites passed."
