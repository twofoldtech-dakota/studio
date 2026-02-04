<p align="center">
  <img src="https://img.shields.io/badge/version-5.0-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/platform-Claude%20MCP-purple?style=flat-square" alt="Platform">
</p>

<h1 align="center">🎬 STUDIO</h1>
<p align="center"><strong>AI that plans before it builds, learns from mistakes, and never forgets.</strong></p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-how-it-works">How It Works</a> •
  <a href="#-commands">Commands</a> •
  <a href="#-scripts">Scripts</a> •
  <a href="docs/STUDIO-GUIDE.md">Full Guide</a>
</p>

---

## The Problem

Most AI coding assistants:
- ❌ Assume requirements instead of asking
- ❌ Declare success without verification  
- ❌ Forget your preferences between sessions
- ❌ Repeat the same mistakes

**STUDIO fixes this.**

---

## 🚀 Quick Start

```bash
# Install
/plugin marketplace add https://github.com/twofoldtech-dakota/studio.git
/plugin install studio@twofoldtech-dakota

# Plan something
/studio "Add user authentication with email verification"

# Build the plan
/build task_xxx
```

That's it. STUDIO asks questions, creates a plan, and executes with validation.

---

## 🔄 How It Works

```
   YOU                    STUDIO                   OUTPUT
    │                        │                        │
    │  "Add auth"            │                        │
    ├───────────────────────►│                        │
    │                        │                        │
    │   ◄── Questions ───────┤  (3 rounds)           │
    │   ─── Answers ────────►│                        │
    │                        │                        │
    │   ◄── Plan ────────────┤  (review & approve)   │
    │   ─── "looks good" ───►│                        │
    │                        │                        │
    │                        ├───────────────────────►│ Code
    │                        │  Build + Validate      │ Tests
    │                        │  Quality Gates         │ Docs
    │                        │  Learn & Remember      │
    │                        │                        │
```

### The Pipeline

| Phase | What Happens | Script |
|-------|--------------|--------|
| **Plan** | Questions → Requirements → Steps | `confidence-score.sh` |
| **Validate** | Structure check, confidence ≥70 | `validate-plan.sh` |
| **Pre-check** | Lint, types, existing issues | `quality-precheck.sh` |
| **Build** | Execute steps, track progress | `step-progress.sh` |
| **Verify** | Acceptance criteria, DoD | `verify-ac.sh`, `dod-check.sh` |
| **Learn** | Capture patterns, evolve knowledge | `sprint-evolution.sh` |

---

## 📋 Commands

| Command | Alias | What it does |
|---------|-------|--------------|
| `/studio "goal"` | `/s` | Start planning with questions |
| `/build task_xxx` | `/b` | Execute an approved plan |
| `/build --resume` | | Continue from last step |
| `/status` | | Check current task state |

> See [docs/QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md) for all commands.

---

## 🔧 Scripts

All scripts output JSON, have `--help`, and live in `scripts/`.

### Quality Pipeline

```bash
# Before build
./scripts/validate-plan.sh --task-id task_xxx     # Structure check
./scripts/confidence-score.sh --task-id task_xxx  # Quality score (0-100)
./scripts/quality-precheck.sh                      # Lint + typecheck

# During build  
./scripts/step-progress.sh status task_xxx        # Track progress
./scripts/error-matcher.sh --input "error text"   # Fix suggestions

# After build
./scripts/verify-ac.sh --task-id task_xxx         # Acceptance criteria
./scripts/dod-check.sh --auto-detect              # Definition of Done
```

### Confidence Scoring

Plans are scored 0-100:

| Category | Points | Checks |
|----------|--------|--------|
| Requirements | 25 | User confirmations, edge cases, scope |
| Step Quality | 25 | Success criteria, atomic actions |
| Context | 25 | Constraints, quality requirements |
| Risk | 25 | Retry behavior, failure handling |

**≥85** = PROCEED • **70-84** = CAUTION • **<70** = BLOCKED

---

## 🧠 Knowledge System

STUDIO learns from every build:

| Section | Purpose |
|---------|--------|
| **Strict Constraints** | Rules that must never be violated |
| **Slop Ledger** | Naming/structural mistakes to avoid |
| **Performance Delta** | Measured improvements with metrics |
| **Pending Queue** | Signals awaiting promotion |

Every 5 tasks → automatic evolution proposals.

---

## 📁 Project Structure

```
studio/
├── commands/           # /studio, /build definitions
├── scripts/            # Quality pipeline scripts
├── hooks/              # Lifecycle automation
├── schemas/            # JSON validation
├── agents/             # Planner, Builder, Content Writer
├── skills/             # Domain-specific context
├── data/
│   ├── dod-templates/  # Definition of Done templates
│   └── error-patterns.yaml
└── docs/               # Detailed documentation
```

---

## 📚 Documentation

| Doc | Description |
|-----|-------------|
| [STUDIO Guide](docs/STUDIO-GUIDE.md) | Complete usage guide |
| [Architecture](docs/ARCH.md) | System design deep-dive |
| [Quick Reference](docs/QUICK-REFERENCE.md) | Command cheat sheet |
| [AGENTS.md](AGENTS.md) | For AI agents working here |

---

## 🧪 Development

```bash
make test           # Run all tests
make test-quick     # Fast validation only
make lint           # Lint bash scripts
make validate       # Validate JSON/YAML
```

---

<p align="center">
  <sub>Built for developers who want AI that thinks before it codes.</sub>
</p>
