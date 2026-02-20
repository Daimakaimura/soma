# soma

A memory structure and prompt protocol that gives any LLM coding agent a persistent body and self.

## What it is

soma turns any LLM coding agent (Claude Code, OpenCode, Codex) into a persistent,
embodied caretaker for a physical machine. It provides the memory, identity, and
sensing structure that a stateless LLM lacks. The LLM provides the intelligence,
tool use, and reasoning that shell scripts can't. The LLM backend is fully
abstracted — use Anthropic, Google, OpenAI, or local models via Ollama.

soma is not a framework, not an agent loop, not a monitoring system.
It's a set of files: prompts, memory, and a thin wrapper.

## How it works

```
prompts/          ← the genome (what to do in each mode)
    seed.md       ← YOU write this: what is this machine?
    birth.md      ← drives self-discovery and research
    cycle.md      ← routine interoception
    query.md      ← answer external questions
    auditor.md    ← independent drift detection

memory/           ← the mind (agent reads and writes these)
    self.md       ← "what I know about myself" — living document
    lessons.md    ← "what I've learned" — accumulates over time
    journal/      ← daily narrative, append-only
    summaries/    ← weekly compressed summaries
    .versions/    ← automatic backups of critical files (last 10 each)

lib/
    sense.sh      ← agent-written sensing script (born during birth)
    reflex.sh     ← hardcoded emergency responses (no LLM needed)

soma              ← bash wrapper: assembles context, invokes the agent
soma.env          ← config: which backend, which model, autonomy, body access
```

### LLM backend is abstracted

soma doesn't care what LLM you use. The wrapper calls one of:

| Backend    | Invocation                                          | Notes |
|------------|-----------------------------------------------------|-------|
| `opencode` | `opencode run --model provider/model "prompt"`      | 75+ providers, local via Ollama |
| `claude`   | `claude -p --model sonnet "prompt"`                 | Claude Code (Pro/Max subscription) |
| `codex`    | `codex -q "prompt"`                                 | OpenAI Codex |

Set `SOMA_AGENT` and `SOMA_MODEL` in `soma.env`. Examples:

```bash
# Claude via OpenCode
SOMA_AGENT=opencode
SOMA_MODEL=anthropic/claude-sonnet-4-20250514

# Gemini via OpenCode
SOMA_AGENT=opencode
SOMA_MODEL=google/gemini-2.5-pro

# Local model via Ollama (free, private, works offline)
SOMA_AGENT=opencode
SOMA_MODEL=ollama/qwen3-coder-30b

# Claude Code directly (needs Pro/Max subscription)
SOMA_AGENT=claude
SOMA_MODEL=sonnet
```

## Quickstart

```bash
# 1. Get soma
git clone <repo> /opt/soma
cd /opt/soma

# 2. Edit the seed — describe the machine in 2-3 sentences
nano prompts/seed.md

# 3. Configure
nano soma.env
# Set SOMA_AGENT, SOMA_MODEL, SOMA_BODY, SOMA_AUTONOMY

# 4. Birth — agent discovers itself, researches hardware, builds self-knowledge
#    This takes 30-90 min.
./soma birth

# 5. Verify
./soma status
cat memory/self.md

# 6. Start cycling
cat > /etc/systemd/system/soma.service << 'EOF'
[Unit]
Description=soma interoception cycle
[Service]
Type=oneshot
WorkingDirectory=/opt/soma
ExecStart=/opt/soma/soma cycle
TimeoutSec=180
EOF

cat > /etc/systemd/system/soma.timer << 'EOF'
[Unit]
Description=soma cycle timer
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now soma.timer

# 7. Weekly audit
echo "0 3 * * 0 /opt/soma/soma audit" | crontab -
```

## Autonomy levels

Control what the agent can do via `SOMA_AUTONOMY` in `soma.env`:

| Level       | Can read | Can run commands | Can modify system | Can write memory |
|-------------|----------|-----------------|-------------------|-----------------|
| `observe`   | yes      | no              | no                | no (stdout only) |
| `suggest`   | yes      | read-only       | no                | yes             |
| `act_safe`  | yes      | yes             | low-risk only     | yes             |
| `act_full`  | yes      | yes             | yes               | yes             |

Start with `suggest`. Promote to `act_safe` once you trust the agent's judgment.
`act_full` is for mature agents on non-critical machines.

The autonomy level is included in the prompt header and the cycle/query prompts
instruct the agent to respect it. This is a soft constraint (enforced by prompt,
not by code) — it's a guardrail, not a sandbox.

## Deployment models

### Embodied (agent lives on the machine)

```bash
SOMA_BODY=local
```

### Remote (agent reaches body via SSH)

```bash
# Prefer a dedicated user over root
SOMA_BODY=ssh://soma@192.168.2.1
```

Best for: firewalls, appliances, machines where you don't want extra software.

### Multiple agents

Each body gets its own soma directory:

```
/opt/soma/epyc/           SOMA_BODY=local
/opt/soma/firewall/       SOMA_BODY=ssh://soma@192.168.2.1
/opt/soma/truenas/        SOMA_BODY=ssh://soma@192.168.2.123
```

## Talking to an agent

```bash
./soma query "how are you doing?"
ssh host "/opt/soma/soma query 'how are you?'"
```

## Robustness

- **Reboot**: systemd timer restarts automatically. Agent reads journal, notices gap.
- **Crash mid-cycle**: next timer tick starts fresh. All state is on disk.
- **Concurrent cycles**: `flock` ensures only one cycle runs at a time. Overlapping
  invocations exit cleanly. Queries and audits block-wait (up to 120s) so the user
  gets an answer rather than a skip.
- **LLM offline**: reflex.sh handles emergencies without LLM. Sensor data keeps
  being archived. Heartbeat only updates on success, so monitoring accurately
  reflects agent health.
- **Disk full**: reflex.sh cleans caches before cycle runs.
- **Bad LLM output**: critical files (self.md, lessons.md, sense.sh) are backed up
  before every cycle. Last 10 versions kept in `memory/.versions/`.
- **Accidental rebirth**: `soma birth` refuses if self-knowledge exists.
  Requires `--force` (which backs up first).
- **Special chars in data**: context assembly uses `cat` heredocs and `printf`,
  not bash string substitution. `}`, `$`, backticks in sensor data pass through
  cleanly.
- **Context overflow**: smart truncation preserves head (template, seed, self) and
  tail (sensor readings), drops journal/summary from the middle first.
- **Hung commands**: every `body_exec`, `scp`, `ssh`, and sensor collection has
  an explicit `timeout`. Failed commands include exit code in output.
  `sense.sh` failure falls back to minimal built-in collection.
- **Agent skips journaling**: post-cycle verification adds a stub entry if the
  agent didn't write one.
- **Audit not written**: verified and stubbed like journal entries.
- **Soma fills its own disk**: reflex.sh monitors `run/` footprint, prunes if >500MB.
- **Prompt injection via logs**: all prompts include explicit untrusted-data
  warnings. Auditor checks for injection susceptibility. Autonomy levels
  limit blast radius even if injection succeeds.
- **Glob expansion under set -e**: all `ls *.ext` patterns are `|| true` guarded.
  No first-run crashes from missing files.

## Reflexes (lib/reflex.sh)

Hardcoded, no-LLM emergency responses. Run before every cycle.

- **Soma footprint** >500MB → prune old readings and temp files
- **Disk** >95% full → emergency cleanup (apt cache, journal, /tmp)
- **CPU temp** critical → throttle (portable awk parsing, no grep -P)
- **Memory** <2% available → drop caches
- **ZFS pool** DEGRADED/FAULTED → log alert

## Design principles

1. **LLM-agnostic.** Use Claude, Gemini, GPT, or a local model via Ollama.
2. **The agent builds its own senses.** sense.sh is agent-authored during birth.
3. **Memory is files.** No database. `cat self.md` to see the agent's mind.
4. **Communication is pull.** Agents ask when they need to know, not broadcast.
5. **The auditor is not the agent.** Drift detection needs an outside perspective.
6. **Raw data anchors beliefs.** Sensor readings are ground truth.
7. **Seed is immutable.** It's the agent's fixed point of identity.
8. **Safe by default.** Autonomy starts at `suggest`. Untrusted data is labelled.
   Prefer a dedicated user over root.
