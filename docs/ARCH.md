---
title: STUDIO Architecture
version: 5.0.0
type: architecture
audience: [developers, ai-agents, contributors]
last_updated: 2026-02-02
---

# STUDIO Architecture Reference

> Technical architecture documentation for the STUDIO orchestration system.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Agent Architecture](#agent-architecture)
3. [Hook System](#hook-system)
4. [Knowledge System](#knowledge-system)
5. [Context Management](#context-management)
6. [Enterprise Decomposition](#enterprise-decomposition)
7. [Script Reference](#script-reference)
8. [File Locations](#file-locations)

---

## System Overview

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              STUDIO v5.0.0                                        │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │                           ORCHESTRATION LAYER                               │  │
│  │                                                                            │  │
│  │  hooks.json ─────────▶ Hook Execution ─────────▶ Agent Coordination       │  │
│  │       │                     │                          │                   │  │
│  │       ▼                     ▼                          ▼                   │  │
│  │  PreCommand/build     SubagentStart            SubagentStop                │  │
│  │  SessionStart         PreToolUse               Stop                        │  │
│  │                                                                            │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐   ┌───────────────────────────┐  │
│  │                   │   │                   │   │                           │  │
│  │   🔵 PLANNER      │──▶│   🟡 BUILDER      │──▶│   📚 LEARN PHASE         │  │
│  │                   │   │                   │   │                           │  │
│  │  agents/          │   │  agents/          │   │  Self-learning           │  │
│  │  planner.yaml     │   │  builder.yaml     │   │  protocol                 │  │
│  │                   │   │                   │   │                           │  │
│  └───────────────────┘   └───────────────────┘   └───────────────────────────┘  │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │                           KNOWLEDGE LAYER                                   │  │
│  │                                                                            │  │
│  │  STUDIO_KNOWLEDGE_BASE.md                                                  │  │
│  │  ├── Strict Constraints  (NEVER VIOLATE rules)                            │  │
│  │  ├── Slop Ledger         (Naming/structural mistakes)                     │  │
│  │  ├── Performance Delta   (Measured improvements)                          │  │
│  │  └── Pending Queue       (Awaiting promotion)                             │  │
│  │                                                                            │  │
│  │  studio/learnings/*.md   (Domain-specific patterns)                       │  │
│  │  .studio/sprint-counter.json (Evolution tracking)                         │  │
│  │                                                                            │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │                           CONTEXT LAYER                                     │  │
│  │                                                                            │  │
│  │  Tier 0: Invariants (5K)   │ Always loaded, never summarized              │  │
│  │  Tier 1: Active (30K)      │ Current task context                         │  │
│  │  Tier 2: Summarized (15K)  │ Recent context, compressed                   │  │
│  │  Tier 3: Indexed (5K)      │ On-demand reference lookup                   │  │
│  │                                                                            │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
USER REQUEST ("/build goal")
       │
       ▼
┌──────────────────────────────────────┐
│  PreCommand/build Hook               │
│  ├── Initialize orchestration        │
│  ├── Route goal to workflow          │
│  └── Inject knowledge base           │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  SubagentStart Hook                  │
│  ├── Load handoff context            │
│  ├── Detect and inject skills        │
│  └── Inject strict constraints       │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  PLANNER AGENT                       │
│  ├── Gather context                  │
│  ├── Iterative questioning           │
│  ├── Plan construction               │
│  └── Challenge & confidence scoring  │
└──────────────────────────────────────┘
       │
       ▼ (Handoff: task_id, plan_path)
┌──────────────────────────────────────┐
│  BUILDER AGENT                       │
│  ├── Execute plan steps              │
│  ├── Validate each step              │
│  ├── Retry on failure                │
│  └── Quality gates                   │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  SubagentStop/builder Hook           │
│  ├── Self-learning protocol          │
│  ├── Classify learning               │
│  ├── Save to knowledge base          │
│  └── Increment sprint counter        │
└──────────────────────────────────────┘
       │
       ▼
   COMPLETE (or EVOLUTION_DUE if 5th task)
```

---

## Agent Architecture

### Planner Agent

**File:** `agents/planner.yaml`

| Property | Value |
|----------|-------|
| Model | claude-sonnet-4-20250514 |
| Phase Color | Blue |
| Primary Playbook | planning |
| Capabilities | Context gathering, questioning, plan construction, SICVF validation |

**Phases:**

1. **Context Gathering** — Load learnings, scan codebase, check git, query Context7
2. **Enterprise Decomposition** (optional) — For 10+ task projects, generate decomposition map
3. **Iterative Questioning** — Ask clarifying questions in rounds until requirements clear
4. **Plan Construction** — Create atomic steps with acceptance criteria and quality gates

**Outputs:**

```
.studio/tasks/${TASK_ID}/plan.json
.studio/tasks/${TASK_ID}/manifest.json
```

### Builder Agent

**File:** `agents/builder.yaml`

| Property | Value |
|----------|-------|
| Model | claude-sonnet-4-20250514 |
| Phase Color | Gold |
| Primary Playbook | building |
| Capabilities | Plan execution, validation, retry, quality gates, learning capture |

**Execution Loop:**

```
FOR EACH step IN plan:
    EXECUTE micro-actions
    OBSERVE via validation command
    IF FAIL:
        DECIDE: RETRY (≤5x) | REPLAN | ESCALATE
    IF PASS:
        Continue to next step

RUN quality gates (lint, typecheck, test)
CAPTURE learnings (self-learning protocol)
```

### Content Writer Agent

**File:** `agents/content-writer.yaml`

| Property | Value |
|----------|-------|
| Model | claude-sonnet-4-20250514 |
| Phase Color | Purple |
| Primary Playbooks | brand, content |
| Capabilities | Brand-aligned content creation, SEO optimization |

---

## Hook System

**File:** `hooks/hooks.json` (v5.0.0)

### Hook Lifecycle

```
SessionStart
    │
    ▼
PreCommand/{command}
    │
    ▼
SubagentStart
    │
    ▼
PreToolUse
    │
    ▼
PostToolUse / PostToolUseFailure
    │
    ▼
SubagentStop
    │
    ▼
Stop
```

### Hook Types

| Type | Description | Timeout |
|------|-------------|---------|
| `prompt` | Quick LLM evaluation | Default |
| `command` | Shell script execution | Default |
| `agent` | Full agent invocation | 180s |

### Key Hooks

#### PreCommand/build

- Initializes orchestration session
- Routes goal to workflow (build_only, plan_then_build, multi_task, decompose)
- Injects knowledge base constraints

#### SubagentStart

- Loads handoff context from previous agent
- Detects and injects relevant skills
- Injects Strict Constraints as "NEVER VIOLATE" list
- Injects relevant Slop Ledger entries

#### SubagentStop/builder

- Triggers self-learning protocol
- Classifies learning using signal-audit.sh
- Saves to appropriate knowledge base section
- Increments sprint counter
- Checks if evolution is due

---

## Knowledge System

### Architecture

```
STUDIO_KNOWLEDGE_BASE.md (Root)
├── Strict Constraints     # Rules that MUST NOT be violated
│   └── Promotion: 2+ occurrences
├── Slop Ledger           # Naming/structural mistakes to avoid
│   └── Promotion: 1 occurrence + rework cost
├── Performance Delta     # Measured improvements with numbers
│   └── Requirement: Quantified metrics
└── Pending Queue         # Signals awaiting promotion
    └── After 2nd occurrence → Strict Constraints

studio/learnings/*.md (Domain-specific)
├── global.md
├── frontend.md
├── backend.md
├── testing.md
├── security.md
└── performance.md
```

### Signal Classification Flow

```
Learning Input
      │
      ▼
┌──────────────────────────────────────┐
│  NOISE CHECK                         │
│  ├── No task_id? → DISCARD           │
│  ├── Contains "how to"? → DISCARD    │
│  ├── Generic concept? → DISCARD      │
│  └── No impact? → DISCARD            │
└──────────────────────────────────────┘
      │ (passes)
      ▼
┌──────────────────────────────────────┐
│  TYPE DETECTION                      │
│  ├── Has metrics? → PERFORMANCE      │
│  ├── Error keywords? → ERROR         │
│  ├── Naming issue? → CONVENTION      │
│  ├── Framework match? → FRAMEWORK    │
│  └── Default → PATTERN               │
└──────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────┐
│  ROUTING                             │
│  ├── PERFORMANCE → Performance Delta │
│  ├── ERROR (1st) → Pending Queue     │
│  ├── ERROR (2+) → Strict Constraints │
│  ├── CONVENTION → Slop Ledger        │
│  ├── FRAMEWORK → Pending Queue       │
│  └── PATTERN → Domain learnings      │
└──────────────────────────────────────┘
```

### Sprint Evolution Protocol

**Trigger:** Every 5 completed tasks

```
┌──────────────────────────────────────┐
│  PROPOSAL GENERATION                 │
│                                      │
│  1. DELETABLE RULES                  │
│     Scan Strict Constraints for:     │
│     - No violations in 10+ tasks     │
│     - May be obsolete                │
│                                      │
│  2. NEW ENFORCEMENT RULES            │
│     Scan Pending Queue for:          │
│     - Items with 2+ occurrences      │
│     - High-impact patterns           │
└──────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  USER REVIEW                         │
│                                      │
│  Accept / Reject each proposal       │
│  Approved → Update knowledge base    │
│  Reset sprint counter                │
└──────────────────────────────────────┘
```

---

## Context Management

### 4-Tier Context System

| Tier | Name | Budget | Persistence | Use Case |
|------|------|--------|-------------|----------|
| 0 | Invariants | 5K tokens | Always loaded | Core constraints, project identity |
| 1 | Active | 30K tokens | Per-task | Current task context, plan, code |
| 2 | Summarized | 15K tokens | Compressed | Recent tasks, summarized |
| 3 | Indexed | 5K tokens | On-demand | Reference lookup, search |

### Context Budget Pools

| Pool | Purpose | Warning | Critical |
|------|---------|---------|----------|
| reserved | System overhead | 80% | 95% |
| learnings | Domain knowledge | 80% | 95% |
| backlog | Pending tasks | 80% | 95% |
| plans | Active plans | 80% | 95% |
| context7 | Library docs cache | 80% | 95% |
| working | Agent workspace | 80% | 95% |

### Context Injection

**Script:** `scripts/context-inject.sh`

```bash
# Inject context for a task
./scripts/context-inject.sh --task-id <task_id> --goal "<goal>"
```

**Injection Order:**

1. Tier 0: Invariants (from `studio/context/invariants.md`)
2. Knowledge Base: Strict Constraints relevant to goal
3. Knowledge Base: Slop Ledger entries for detected domains
4. Domain Learnings: Relevant patterns
5. Skill Context: Guidelines and questions

---

## Enterprise Decomposition

### SICVF Validation Protocol

**Script:** `scripts/sicvf-validate.sh`

Every task must pass:

| Criterion | Validation |
|-----------|------------|
| **S**ingle-pass | Can complete in one build cycle without external dependencies |
| **I**ndependent | No circular dependencies in task graph |
| **C**lear boundaries | Well-defined inputs, outputs, and acceptance criteria |
| **V**erifiable | Has executable validation commands |
| **F**its context | Within token budget (typically 30K active tier) |

```bash
# Validate a task
./scripts/sicvf-validate.sh --task-id <task_id>

# Output: PASS or FAIL with specific criterion failures
```

### Decomposition Map

For projects with 10+ tasks, the Planner generates:

1. **Pillar Analysis** — Score 6 architectural pillars (0-10 each):
   - Data (persistence, models)
   - Auth (authentication, authorization)
   - API (endpoints, contracts)
   - UI (components, flows)
   - Integration (external services)
   - Infra (deployment, monitoring)

2. **Hierarchy** — Three-level decomposition:
   ```
   EPIC (large initiative)
   └── FEATURE (user-facing capability)
       └── TASK (atomic, SICVF-validated)
   ```

3. **Dependency Graph** — DAG with:
   - Critical path identification
   - Parallel batch calculation
   - Blocking relationship mapping

4. **Context Plan** — Defines what goes in each tier:
   - Tier 0: Project invariants, tech stack, patterns
   - Tier 1: Current epic/feature context
   - Tier 2: Completed task summaries
   - Tier 3: Reference docs, schemas

**Protocol:** `studio/prompts/enterprise-decomposition.md`

---

## Script Reference

### Core Scripts

| Script | Purpose | Key Commands |
|--------|---------|--------------|
| `learnings.sh` | Learning capture | `classify`, `check-duplicate`, `extract-metrics`, `detect` |
| `signal-audit.sh` | Signal classification | `classify`, `is-noise`, `detect-type` |
| `sprint-evolution.sh` | Sprint evolution | `status`, `increment`, `propose`, `reset` |
| `orchestrator.sh` | Multi-agent coordination | `init`, `route`, `handoff`, `checkpoint`, `resume` |
| `context-manager.sh` | Context budget | `status`, `scan`, `optimize` |
| `context-inject.sh` | Context injection | `--task-id`, `--goal` |
| `sicvf-validate.sh` | Task validation | `--task-id` |
| `skills.sh` | Skill detection | `detect`, `inject`, `list` |
| `output.sh` | Terminal formatting | `header`, `phase`, `agent`, `status` |
| `backlog.sh` | Backlog management | `add`, `list`, `prioritize` |

### Usage Examples

```bash
# Classify a learning
./scripts/signal-audit.sh classify "Fixed auth bug in task_001"

# Check sprint status
./scripts/sprint-evolution.sh status

# Detect skills for a goal
./scripts/skills.sh detect "Add OAuth authentication"

# Validate task SICVF
./scripts/sicvf-validate.sh --task-id task_20260202_auth

# Check context budget
./scripts/context-manager.sh status
```

---

## File Locations

### Configuration Files

| File | Purpose |
|------|---------|
| `hooks/hooks.json` | Hook definitions (v5.0.0) |
| `agents/*.yaml` | Agent configurations |
| `studio/config/tracked-frameworks.json` | Framework signal detection |
| `.studio/sprint-counter.json` | Sprint evolution state |

### Knowledge Files

| File | Purpose |
|------|---------|
| `STUDIO_KNOWLEDGE_BASE.md` | Master knowledge base |
| `studio/learnings/*.md` | Domain-specific patterns |
| `studio/rules/*.md` | Memory rules (legacy) |
| `studio/context/invariants.md` | Project invariants |

### Prompt Files

| File | Purpose |
|------|---------|
| `studio/prompts/self-learning.md` | Self-learning protocol |
| `studio/prompts/enterprise-decomposition.md` | Enterprise workflow |

### Playbooks

| Directory | Purpose |
|-----------|---------|
| `playbooks/planning/SKILL.md` | Plan-and-Solve methodology |
| `playbooks/building/SKILL.md` | Plan-and-Execute methodology |
| `playbooks/validation/SKILL.md` | Challenge + confidence scoring |
| `playbooks/memory/SKILL.md` | Learning system |
| `playbooks/orchestration/SKILL.md` | Multi-agent coordination |
| `playbooks/context-management/SKILL.md` | Context optimization |

### Generated Files

| Location | Generated By | Purpose |
|----------|--------------|---------|
| `.studio/orchestration/*/state.json` | Orchestrator | Session state |
| `.studio/tasks/*/plan.json` | Planner | Execution plan |
| `.studio/tasks/*/manifest.json` | Builder | Task state |
| `studio/data/analytics.json` | Analytics | Build metrics |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 5.0.0 | 2026-02-02 | Dynamic SOP System, Sprint Evolution, Knowledge Base |
| 4.0.0 | 2026-02-01 | Enterprise Decomposition, SICVF, 4-Tier Context |
| 3.0.0 | - | Multi-agent Orchestration |
| 2.0.0 | - | Hook System |
| 1.0.0 | - | Initial Release |

---

*Built with precision. Executed with confidence. Learned continuously.*
