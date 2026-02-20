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
    local query_output
    local journal_file
    local audit_file
    local latest_raw

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

    SOMA_FAKE_MODE=birth ./soma birth >/tmp/${suite_name}-birth.log 2>&1
    SOMA_FAKE_MODE=cycle ./soma cycle >/tmp/${suite_name}-cycle.log 2>&1
    query_output="$(SOMA_FAKE_MODE=query ./soma query "status?" 2>/tmp/${suite_name}-query.log)"
    SOMA_FAKE_MODE=audit ./soma audit >/tmp/${suite_name}-audit.log 2>&1

    test -s memory/self.md
    test -s memory/lessons.md
    test -x lib/sense.sh
    journal_file="$(find memory/journal -maxdepth 1 -type f -name '*.md' -print | sort | tail -n 1)"
    test -n "$journal_file"
    test -s "$journal_file"
    test -s run/heartbeat
    audit_file="$(find run -maxdepth 1 -type f -name 'audit-*.md' -print | sort | tail -n 1)"
    test -n "$audit_file"
    test -s "$audit_file"

    if ! printf '%s\n' "$query_output" | grep -q "fake response"; then
        echo "query output did not contain fake response for ${suite_name}" >&2
        printf '%s\n' "$query_output" >&2
        exit 1
    fi

    latest_raw="$(find run/raw -maxdepth 1 -type f -name '*.txt' -print | sort | tail -n 1)"
    test -n "$latest_raw"
    test -s "$latest_raw"
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
