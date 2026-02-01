# STUDIO

**AI builds code. STUDIO makes sure it's correct.**

---

## Architecture

```
GOAL ──→ PLAN ──→ BUILD ──→ VERIFIED
           │         │
           │         └── execute steps
           │             validate each
           │             retry on fail
           │
           └── gather requirements
               embed context
               define validation
```

---

## Capabilities

- **Asks before assuming** — Probes scope, edge cases, success criteria
- **Plans before executing** — Atomic steps with validation commands
- **Verifies before completing** — Quality gates block incomplete work
- **Learns from corrections** — Memory persists per-project

---

## Problem → Solution

| AI Failure | Fix |
|------------|-----|
| Assumes requirements | Mandatory interrogation phase |
| Declares success early | Quality gate blocks completion |
| Drifts from intent | Plan anchors execution |
| Forgets corrections | Memory persists rules |

---

## Stack

| | |
|-|-|
| Runtime | Claude Code Plugin |
| Agents | YAML (Planner, Builder) |
| Validation | JSON Schema |
| Storage | File-based |

---

## Quick Start

```bash
npm install -g @anthropic-ai/claude-code
claude
/plugin marketplace add twofoldtech-dakota/studio
/plugin install studio@studio-marketplace
/build "your goal here"
```

---

## Commands

| | |
|-|-|
| `/build <goal>` | Start build |
| `/build:preview` | Preview plan |
| `/build:interactive` | Step-by-step |
| `/build resume` | Continue |
| `/build status` | Check state |
| `/build abort` | Cancel |

---

## License

MIT
