# STUDIO Quick Reference

> Copy-paste ready commands and scripts for daily use.

---

## 🚀 Essential Commands

| Command | Alias | What it does |
|---------|-------|--------------|
| `/studio "goal"` | `/s` | **Start planning** - asks questions, creates plan |
| `/build task_xxx` | `/b` | **Execute plan** - runs validated build |
| `/build --resume` | | Continue from last completed step |
| `/status` | | Check current task state |

---

## 🛠 Quality Pipeline Scripts

All scripts output JSON. Run with `--help` for options.

### Before Build
```bash
./scripts/validate-plan.sh --task-id task_xxx   # Structure check
./scripts/confidence-score.sh --task-id task_xxx # Score 0-100
./scripts/quality-precheck.sh                    # Lint + typecheck
```

### During Build
```bash
./scripts/step-progress.sh status task_xxx      # Progress tracker
./scripts/error-matcher.sh --input "error..."   # Get fix suggestions
```

### After Build
```bash
./scripts/verify-ac.sh --task-id task_xxx       # Run acceptance criteria
./scripts/dod-check.sh --auto-detect            # Definition of Done
```

---

## 📊 Confidence Scoring

| Score | Verdict | Action |
|-------|---------|--------|
| **85-100** | ✅ PROCEED | Build with confidence |
| **70-84** | ⚠️ CAUTION | Review warnings first |
| **<70** | 🛑 BLOCKED | Fix issues before build |

Scored across: Requirements (25) + Step Quality (25) + Context (25) + Risk (25)

---

## 📁 Build States

| State | Icon | Meaning |
|-------|------|---------|
| `PLANNING` | 🔵 | Planner asking questions |
| `READY_TO_BUILD` | 📋 | Plan approved, ready to go |
| `BUILDING` | 🟡 | Builder executing steps |
| `COMPLETE` | ✅ | Done, quality gate passed |
| `BLOCKED` | 🛑 | Quality gate failed |
| `HALTED` | ⚠️ | Step failed after retries |

---

## 🧠 Learning System

```bash
# Sprint evolution (auto-triggers every 5 tasks)
./scripts/sprint-evolution.sh status    # Current sprint progress
./scripts/sprint-evolution.sh propose   # Generate evolution proposals

# Signal classification
./scripts/signal-audit.sh classify "learning text"  # Route to correct section
./scripts/learnings.sh check-duplicate "title"      # Avoid duplicates
```

### Knowledge Base Sections

| Section | What goes here |
|---------|----------------|
| **Strict Constraints** | Rules that must NEVER be violated (auto-promoted after 2 hits) |
| **Slop Ledger** | Naming/structural mistakes to avoid |
| **Performance Delta** | Measured improvements with before/after metrics |
| **Pending Queue** | Signals awaiting promotion |

---

## 🏗 Enterprise Scripts

```bash
# SICVF validation (large projects)
./scripts/sicvf-validate.sh --task-id task_xxx

# Context management
./scripts/context-manager.sh status              # Check budgets
./scripts/context-inject.sh --task-id task_xxx   # Load tiered context

# Multi-agent orchestration
./scripts/orchestrator.sh init "goal"            # Start session
./scripts/orchestrator.sh checkpoint "name"      # Save state
./scripts/orchestrator.sh recover                # Resume from failure

# Parallel execution
./scripts/parallel-build.sh --session-id orch_xxx  # Run independent tasks
./scripts/dependency-graph.sh parallel-batches     # Find parallelizable work
```

---

## 📎 Quick Workflows

### Build a Feature
```bash
/studio "Add user authentication"    # 1. Plan (answers questions)
# Review plan, approve
/build task_20260204_123456          # 2. Execute
```

### Resume Failed Build
```bash
/build --resume                      # Continues from last completed step
```

### Check Why Build Failed
```bash
./scripts/error-matcher.sh --input "$(cat .studio/tasks/task_xxx/error.log)"
# Returns: pattern match, fix suggestion, auto-fix command
```

### Validate Before Build
```bash
./scripts/validate-plan.sh --task-id task_xxx && \
./scripts/confidence-score.sh --task-id task_xxx
```

---

## 📂 Key Files

| File | Purpose |
|------|---------|
| `commands/studio.md` | Planning command definition |
| `commands/build.md` | Build command definition |
| `hooks/hooks.json` | Lifecycle automation |
| `data/error-patterns.yaml` | Error → fix mappings |
| `data/dod-templates/` | Definition of Done templates |
| `STUDIO_KNOWLEDGE_BASE.md` | Learned constraints |
| `.studio/` | Runtime state (gitignored) |

---

## 🎯 SICVF Criteria

Tasks must pass all 5 to be buildable:

| Letter | Criterion | Check |
|--------|-----------|-------|
| **S** | Single-pass | Completable in one build cycle |
| **I** | Independent | No circular dependencies |
| **C** | Clear | Well-defined inputs/outputs |
| **V** | Verifiable | Has executable acceptance criteria |
| **F** | Fits context | Within ~30K token budget |

---

## 📊 4-Tier Context

| Tier | Budget | What's loaded |
|------|--------|---------------|
| 0 | 5K | Invariants (always loaded) |
| 1 | 30K | Active task context |
| 2 | 15K | Summarized recent tasks |
| 3 | 5K | On-demand reference |

---

<p align="center"><sub>Plan → Validate → Build → Verify → Learn</sub></p>
