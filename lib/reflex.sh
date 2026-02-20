#!/usr/bin/env bash
# soma/lib/reflex.sh — Hardcoded emergency reflexes (no LLM needed)
#
# Run BEFORE each cycle. Handles situations where waiting for LLM is too slow.
# The brainstem: keeps you alive, doesn't think.
#
# Every pipeline that might not match ends with || true to prevent
# accidental exit under set -euo pipefail.

set -euo pipefail

SOMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REFLEX_LOG="${SOMA_DIR}/run/reflex.log"

mkdir -p "$(dirname "$REFLEX_LOG")"

reflex_log() {
    printf '[%s] [reflex] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$REFLEX_LOG"
}

triggered=0

# --- Soma's own disk footprint ---
if [ -d "${SOMA_DIR}/run" ]; then
    soma_run_kb=$(du -sk "${SOMA_DIR}/run" 2>/dev/null | awk '{print $1}') || true
    if [ -n "${soma_run_kb:-}" ] && [ "$soma_run_kb" -gt 512000 ] 2>/dev/null; then
        reflex_log "WARNING: soma run/ is ${soma_run_kb}KB — pruning"
        find "${SOMA_DIR}/run/raw" -name "*.txt" -mtime +2 -delete 2>/dev/null || true
        find "${SOMA_DIR}/run" -name ".prompt-*" -delete 2>/dev/null || true
        triggered=1
    fi
fi

# --- Disk space emergency ---
root_usage=$(df / 2>/dev/null | awk 'NR==2 {gsub(/%/,""); print $5}') || true
if [ -n "${root_usage:-}" ] && [ "$root_usage" -gt 95 ] 2>/dev/null; then
    reflex_log "EMERGENCY: root filesystem at ${root_usage}%"
    apt-get clean 2>/dev/null || pkg clean -y 2>/dev/null || true
    journalctl --vacuum-time=1d 2>/dev/null || true
    find /tmp -type f -mtime +1 -delete 2>/dev/null || true
    find "${SOMA_DIR}/run/raw" -name "*.txt" -mtime +1 -delete 2>/dev/null || true
    reflex_log "Disk cleanup attempted"
    triggered=1
fi

# --- CPU thermal emergency ---
# Portable: awk instead of grep -P. Handles Tctl (AMD), Package id (Intel).
cpu_temp=$(
    sensors 2>/dev/null | awk '
        /Tctl:/         { gsub(/[^0-9.]/, "", $2); printf "%d", $2; exit }
        /Package id 0:/ { gsub(/[^0-9.]/, "", $4); printf "%d", $4; exit }
    ' || true
)
if [ -n "${cpu_temp:-}" ] && [ "$cpu_temp" -gt 100 ] 2>/dev/null; then
    reflex_log "EMERGENCY: CPU temp ${cpu_temp}°C — throttling"
    if command -v cpupower &>/dev/null; then
        cpupower frequency-set -u 2000MHz 2>/dev/null || true
    fi
    triggered=1
fi

# --- OOM pressure ---
if [ -f /proc/meminfo ]; then
    avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo) || true
    total=$(awk '/MemTotal/ {print $2}' /proc/meminfo) || true
    if [ -n "${avail:-}" ] && [ -n "${total:-}" ] && [ "$total" -gt 0 ] 2>/dev/null; then
        pct=$((avail * 100 / total))
        if [ "$pct" -lt 2 ]; then
            reflex_log "EMERGENCY: memory available ${pct}% — dropping caches"
            sync
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            triggered=1
        fi
    fi
fi

# --- ZFS pool critical ---
if command -v zpool &>/dev/null; then
    while IFS=$'\t' read -r pool health; do
        if [ "$health" = "DEGRADED" ] || [ "$health" = "FAULTED" ]; then
            reflex_log "EMERGENCY: ZFS pool '${pool}' is ${health}"
            triggered=1
        fi
    done < <(zpool list -H -o name,health 2>/dev/null || true)
fi

# --- Report ---
if [ "$triggered" -gt 0 ]; then
    reflex_log "One or more reflexes triggered"
    exit 1
fi

exit 0
