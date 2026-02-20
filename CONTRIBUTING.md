# Contributing

Thanks for contributing to `soma`.

## Scope
`soma` is a shell-first project for LLM-driven machine care. Contributions
should preserve safety, observability, and portability.

## Development Workflow
1. Create a feature branch from `main`.
2. Make focused changes with clear commit messages.
3. Run local checks before opening a PR.
4. Open a PR with context, risk notes, and test evidence.

## Local Checks
Run at minimum:

```bash
bash -n soma lib/reflex.sh
./soma status
```

If available:

```bash
shellcheck soma lib/reflex.sh
```

## Change Guidelines
- Keep `set -euo pipefail` compatibility.
- Avoid weakening safeguards (timeouts, locking, backup/versioning).
- Keep prompt safety language around untrusted data intact.
- Prefer additive changes and document behavior shifts.

## Pull Request Notes
Include:
- What changed and why
- Any operational or safety tradeoffs
- Manual validation steps and outputs
