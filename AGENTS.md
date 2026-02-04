# AGENTS.md

> **Source of Truth**: This file is the authoritative reference for AI agents working in this repository. When docs and AGENTS.md conflict, AGENTS.md wins. Update this file first when making structural changes.

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Build & Development Commands

```bash
# Install dependencies (bats-core for testing, yq for YAML validation)
make install-deps

# Check if dependencies are installed
make check-deps

# Run all tests
make test

# Run quick validation tests only (no state changes)
make test-quick

# Run specific test suites
make test-orchestrator
make test-context-manager
make test-skills
make test-integration

# Lint bash scripts
make lint

# Validate JSON/YAML files
make validate

# Check docs reference real files
make validate-docs

# Generate file listings for docs
make generate-docs

# Run full CI locally
make ci
```

### Running a Single Test

```bash
# Tests use bats-core framework
bats tests/orchestrator.bats           # Run one test file
bats tests/orchestrator.bats -f "init" # Run tests matching pattern
```

### Script Development

Scripts are in `scripts/` and use bash with `set -euo pipefail`. Test scripts require:
- `bats-core` for test execution
- `jq` for JSON manipulation (required)
- `yq` for YAML parsing (optional, skills tests)

## Architecture Overview

### Core Flow

STUDIO is an AI orchestration framework that coordinates multiple agents to complete development tasks:

```
User Goal → Orchestrator → Planner Agent → Builder Agent → Verified Output
                ↓                ↓               ↓
           State Mgmt      Plan Creation   Execution + Learning
```

### Agent System

Agents are defined in `agents/*.yaml`. Each agent has:
- A model assignment
- Capabilities and tools
- Playbooks (methodologies)
- Skills (domain-specific context injection)
- Phase definitions

The three primary agents:
- **Planner** (`agents/planner.yaml`): Creates execution-ready plans through iterative questioning
- **Builder** (`agents/builder.yaml`): Executes plans with validation loops and quality gates
- **Content Writer** (`agents/content-writer.yaml`): Creates brand-aligned content

### Orchestrator (`scripts/orchestrator.sh`)

The orchestrator manages multi-agent workflows. It tracks:
- Session state in `.studio/orchestration/<session_id>/state.json`
- Agent lifecycle (start, complete, fail)
- Handoffs between agents (context passing)
- Checkpoints for recovery
- Failure recovery with retry/replan/escalate thresholds

Key commands:
```bash
./scripts/orchestrator.sh init "goal"           # Start session
./scripts/orchestrator.sh route                 # Route goal to workflow
./scripts/orchestrator.sh agent-start planner   # Mark agent started
./scripts/orchestrator.sh handoff planner builder '{"task_id": "..."}' # Pass context
./scripts/orchestrator.sh checkpoint "name"     # Save recovery point
./scripts/orchestrator.sh recover               # Determine recovery action
```

### Playbook & Skill System

**Playbooks** (`playbooks/*/SKILL.md`) define methodologies—how agents think and work. They contain structured approaches (e.g., Plan-and-Solve for planning, Execute-Observe-Decide for building).

**Skills** (`skills/*.yaml`) provide domain-specific context injection. They are triggered by keywords, file patterns, or domains and inject:
- Checkpoint questions
- Guidelines
- Checklists

Skill detection/injection:
```bash
./scripts/skills.sh detect "Add user authentication"  # Find matching skills
./scripts/skills.sh inject security                   # Get injection content
```

### Hook System (`hooks/hooks.json`)

Hooks wire orchestration to lifecycle events:
- `SessionStart`: Initialize directories, load learnings, check for paused sessions
- `PreCommand`: Triggered before `/build` to initialize orchestration
- `SubagentStart`/`SubagentStop`: Agent lifecycle tracking, skill injection
- `ContextPressure`: Triggered when context budgets are strained

### Knowledge Base System

The knowledge base (`STUDIO_KNOWLEDGE_BASE.md`) contains learned constraints:
- **Strict Constraints**: Rules that must never be violated (promoted after 2+ occurrences)
- **Slop Ledger**: Naming/structural mistakes to avoid
- **Performance Delta**: Measured improvements with before/after metrics
- **Pending Queue**: Signals awaiting promotion

Learning classification:
```bash
./scripts/signal-audit.sh classify "learning text"  # Classify signal type
./scripts/learnings.sh check-duplicate "title"      # Check for duplicates
```

Sprint evolution (every 5 tasks):
```bash
./scripts/sprint-evolution.sh status   # Sprint progress
./scripts/sprint-evolution.sh propose  # Generate evolution proposals
```

### Enterprise Decomposition

For large projects (10+ tasks), the system uses:
- **SICVF Validation**: Tasks must be Single-pass, Independent, Clear, Verifiable, Fits-context
- **4-Tier Context**: Invariants (5K) → Active (30K) → Summarized (15K) → Indexed (5K)
- **Pillar Analysis**: Scores 6 architectural pillars (data, auth, api, ui, integration, infra)

**Auto-detection**: The `/plan` command automatically checks if enterprise decomposition is needed:
```bash
./scripts/decomposition-check.sh status            # Check current state
./scripts/decomposition-check.sh estimate "goal"   # Estimate project scale
./scripts/decomposition-check.sh json "goal"       # JSON output for hooks
```

Triggers when:
- Task count ≥ 5, OR
- Complexity score ≥ 15 (based on goal keywords), OR
- Codebase scale ≥ 20 (large existing codebase)

```bash
./scripts/sicvf-validate.sh --task-id <id>  # Validate task
./scripts/context-inject.sh --task-id <id>  # Inject tiered context
./scripts/context-manager.sh status         # Check context budgets
```

### Data Flow (Plan-First Workflow)

The system enforces a **plan-first workflow**. Raw goals cannot be passed directly to `/build`.

**Correct workflow:**
```bash
/studio "Add user authentication"   # Step 1: Creates plan with mandatory questions
/build task_xxx                     # Step 2: Executes the approved plan
```

**Flow details:**
1. `/studio "goal"` (or `/s`) invokes the Planner agent
2. Planner asks 3 mandatory rounds of questions (scope, technical, edge cases)
3. Planner waits for user confirmation before creating plan
4. Plan is written to `.studio/tasks/<task_id>/plan.json`
5. User runs `/build task_xxx` to execute the approved plan
6. Builder loads plan, executes steps with validation, runs quality gates
7. Learning capture hook extracts patterns to knowledge base
8. Sprint counter increments; evolution proposals generated every 5 tasks

**Why plan-first?**
- Ensures requirements are gathered before coding
- User controls what gets built
- No assumptions that lead to wrong implementations

### State Storage

- `.studio/orchestration/`: Session state, checkpoints
- `.studio/tasks/<task_id>/`: Task plans, manifests
- `.studio/sprint-counter.json`: Evolution tracking
- `studio/learnings/*.md`: Domain-specific learned patterns
- `STUDIO_KNOWLEDGE_BASE.md`: Promoted constraints

### Schema Validation

JSON schemas in `schemas/` define structure for:
- Plans (`plan.schema.json`, `execution-ready-plan.schema.json`)
- Orchestration state (`orchestration-state.schema.json`)
- Context tiers (`context-tiers.schema.json`)
- Skills (`skill.schema.json`)
- Build outputs, learnings, confidence scoring, etc.

## Key Conventions

- All scripts use `STUDIO_DIR` env var (default: `.studio`) for state
- Agent output uses `scripts/output.sh` for consistent terminal formatting
- Task IDs follow pattern: `task_YYYYMMDD_HHMMSS`
- Plan IDs follow pattern: `bp_YYYYMMDD_HHMMSS_XXXX`
- Orchestration sessions: `orch_YYYYMMDD_HHMMSS_XXXX`

## Command Aliases

- `/s` → `/studio` (planning)
- `/b` → `/build`

## Developer Experience Utilities

### Plan Validation
```bash
./scripts/validate-plan.sh --task-id task_xxx  # Validate before build
./scripts/validate-plan.sh --all               # Validate all plans
```

### Error Patterns
`data/error-patterns.yaml` contains common error patterns with fix suggestions. The build loop uses this to provide helpful error messages.

### Skill Caching
Skill detection results are cached in `.studio/.cache/skills/` for 5 minutes. Clear with:
```bash
./scripts/skills.sh clear-cache
```

### Output Utilities
`scripts/output.sh` provides rich terminal output:
```bash
./scripts/output.sh progress_bar 5 10 "Building"     # Progress bar
./scripts/output.sh timing "Plan created" 45          # Timing display
./scripts/output.sh error_box "Type" "Why" "Fix"      # Error with fix suggestion
./scripts/output.sh next_action "Review plan" "/build task_xxx"  # Next action hint
```
