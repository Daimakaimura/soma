# AGENTS.md

## Project Purpose
`soma` is a Bash-based wrapper that gives an LLM coding agent persistent memory and operating routines (`birth`, `cycle`, `query`, `audit`) for machine care.

## Repository Layout
- `soma`: main entrypoint script and command dispatcher.
- `soma.env`: runtime configuration (`SOMA_AGENT`, `SOMA_MODEL`, `SOMA_BODY`, `SOMA_AUTONOMY`).
- `prompts/*.md`: prompt templates and seed input.
- `lib/reflex.sh`: hardcoded emergency reflexes that run before cycles.
- `memory/`: runtime state (self-knowledge, lessons, journal, summaries, backups).

## Working Conventions
- Treat this as a shell-first project. Keep changes portable and explicit.
- Keep `set -euo pipefail` compatibility; avoid brittle command patterns.
- Preserve safety boundaries around untrusted data in prompts and scripts.
- Do not weaken safeguards (timeouts, lock handling, backup/versioning) unless explicitly requested.
- Default to additive, low-risk edits; explain behavior changes in commit messages.

## Validation Checklist
Run these before committing:

```bash
bash -n soma lib/reflex.sh
./soma status
```

If available, also run:

```bash
shellcheck soma lib/reflex.sh
```

## Notes For Agent Changes
- `cycle`, `query`, and `audit` may call external LLM tools (`opencode`, `claude`, `codex`) and can be long-running.
- Prefer testing non-invasive paths (`status`, syntax checks) unless a task explicitly requires full runtime execution.
- When editing prompt templates, keep autonomy-level constraints and untrusted-data warnings intact.
