---
name: orchestration
description: Multi-agent workflow coordination with routing, state management, and failure recovery
triggers:
  - "orchestrate"
  - "coordinate"
  - "workflow"
  - "multi-agent"
---

# Orchestration Skill: Multi-Agent Workflow Coordination

This skill teaches the methodology for coordinating multiple STUDIO agents to accomplish complex goals. The orchestrator is a meta-agent that routes, manages state, handles failures, and coordinates context across the system.

## The Core Problem

Complex software tasks often require multiple specialized agents:
- **Planner**: Requirement gathering, plan construction
- **Builder**: Code execution, validation, quality gates
- **Architect**: Project decomposition, backlog management

Without orchestration:
- Manual handoffs between agents
- Lost context between invocations
- No recovery from failures
- No unified state tracking

## The Orchestrator Role

```
┌─────────────────────────────────────────────────────────────────────┐
│                    THE ORCHESTRATOR                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  RESPONSIBILITIES:                                                  │
│                                                                     │
│  1. ROUTING                                                         │
│     └── Analyze request → Select agent(s) → Determine order        │
│                                                                     │
│  2. STATE MANAGEMENT                                                │
│     └── Track progress → Maintain checkpoints → Handle recovery    │
│                                                                     │
│  3. FAILURE HANDLING                                                │
│     └── Detect failures → Decide: retry | replan | escalate        │
│                                                                     │
│  4. CONTEXT COORDINATION                                            │
│     └── Pass context between agents → Trigger optimization         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Operating Modes

### Implicit Mode (Default)

When users run `/build "goal"`, orchestration happens transparently:

```
User: /build "Add user authentication with OAuth"

[Behind the scenes]
Orchestrator:
  → Analyzes goal complexity
  → Routes to Planner (goal is complex)
  → Handles Planner → Builder handoff
  → Manages any failures
  → Returns unified result

User sees: Seamless planning and building
```

**Key principle**: Users shouldn't need to know orchestration is happening.

### Explicit Mode

When users want visibility and control:

```
User: /orchestrate build

Orchestrator:
  [ROUTING]
  → Goal: "Add user authentication with OAuth"
  → Complexity: HIGH
  → Workflow: plan_then_build
  → Agents: Planner → Builder
  → Confidence: 85%

  Proceed? [y/n]
```

## Workflow Types

### 1. Plan-Then-Build (Default)

```
PLANNER ──────────────→ BUILDER
   │                       │
   ├─ Question loop        ├─ Execute loop
   ├─ Plan construction    ├─ Quality gates
   └─ plan.json            └─ learnings
```

**Triggers**: New features, complex changes, ambiguous requests

### 2. Build-Only

```
BUILDER
   │
   ├─ Load existing plan
   ├─ Execute loop
   └─ Quality gates
```

**Triggers**: Simple fixes, bugs, tasks with existing plans

### 3. Multi-Task Execution

```
BUILDER ──→ BUILDER ──→ BUILDER
   │           │           │
   T1          T2          T3
```

**Triggers**: `/project:run`, batch execution from backlog

### 4. Full Decomposition

```
ARCHITECT ──→ PLANNER ──→ BUILDER
    │            │           │
    ├─ Epics     ├─ Plans    ├─ Execution
    ├─ Features  └─ per task └─ per task
    └─ Tasks
```

**Triggers**: Enterprise projects, large scope requests

## Routing Decision Logic

```
                    ┌──────────────────┐
                    │  Analyze Goal    │
                    └────────┬─────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
     ┌────▼────┐       ┌─────▼─────┐      ┌────▼────┐
     │ Simple  │       │ Complex   │      │  Huge   │
     │fix/bug  │       │ feature   │      │ project │
     └────┬────┘       └─────┬─────┘      └────┬────┘
          │                  │                  │
          ▼                  ▼                  ▼
    BUILD_ONLY        PLAN_THEN_BUILD    DECOMPOSE_FIRST
```

### Routing Signals

| Signal | Workflow |
|--------|----------|
| "fix", "bug", "error", "typo" | build_only |
| "add", "create", "implement" | plan_then_build |
| "refactor", "restructure" | plan_then_build |
| "project", "system", "platform" | decompose_first |
| Existing plan in .studio/tasks/ | build_only |
| Multiple tasks specified | multi_task |

## State Management

### Orchestration State Structure

```yaml
orchestration_state:
  id: "orch_20260202_143052_a1b2"
  mode: "implicit"
  status: "executing"
  goal: "Add user authentication"

  routing:
    workflow: "plan_then_build"
    agent_sequence:
      - agent: "planner"
        status: "completed"
      - agent: "builder"
        status: "active"
    confidence: 0.85

  agent_states:
    - agent: "planner"
      status: "completed"
      output: { plan_id: "bp_xxx" }

    - agent: "builder"
      status: "active"
      current_step: 3

  checkpoints:
    - id: "cp_1706789123"
      name: "planning_complete"
      after_agent: "planner"

  failures: []
```

### Checkpoint Strategy

Save checkpoints after:
1. Each agent completes successfully
2. Before risky operations
3. After significant progress

```bash
./scripts/orchestrator.sh checkpoint "planning_complete"
```

### Resume from Checkpoint

If session interrupted:
```bash
./scripts/orchestrator.sh resume cp_1706789123
```

## Agent Handoffs

When transitioning between agents, context must be passed:

### Planner → Builder Handoff

```yaml
handoff:
  from: "planner"
  to: "builder"
  context:
    task_id: "task_xxx"
    plan_id: "bp_xxx"
    plan_summary: |
      8 steps to implement OAuth:
      1. Install dependencies
      2. Create auth schema
      ...
    learnings_loaded:
      - "security"
      - "backend"
    requirements_summary:
      scope_in: [...]
      scope_out: [...]
```

### Builder → Planner Handoff (on replan)

```yaml
handoff:
  from: "builder"
  to: "planner"
  context:
    failure_reason: "Step 3 failed: API incompatibility"
    completed_steps: [1, 2]
    failed_step: 3
    error_details: "..."
    suggestion: "Consider alternative OAuth library"
```

## Failure Recovery

### Recovery Decision Tree

```
                    ┌──────────────────┐
                    │  Agent Failed    │
                    └────────┬─────────┘
                             │
                    ┌────────▼────────┐
                    │ Is Recoverable? │
                    └────────┬────────┘
                         │       │
                   YES   │       │   NO
                         │       │
              ┌──────────▼───┐   │
              │ Retries Left? │  │
              └──────┬───────┘  │
                 │       │      │
            YES  │       │ NO   │
                 │       │      │
                 ▼       ▼      ▼
              RETRY   REPLAN  ESCALATE
```

### Recovery Actions

#### RETRY
Same agent, same input, increment retry count.
```bash
./scripts/orchestrator.sh agent-start builder  # Re-invoke
```

#### REPLAN
Go back to Planner with failure context.
```bash
./scripts/orchestrator.sh handoff builder planner '{
  "failure_reason": "Step 3 incompatible with existing code",
  "suggestion": "Use different approach"
}'
```

#### ESCALATE
User intervention required.
```
Build failed after 5 retries and 1 replan attempt.

Last error: Cannot resolve OAuth callback URL

Options:
1. [r] Retry with different approach
2. [s] Skip this step (if non-critical)
3. [a] Abort and review plan
```

### Failure Categories

| Category | Action | Example |
|----------|--------|---------|
| Transient | Retry | Network timeout |
| Code Error | Retry with fix | Syntax error |
| Design Flaw | Replan | Wrong approach |
| Blocker | Escalate | Missing dependency |
| Critical | Halt | Security violation |

## Context Budget Coordination

The orchestrator allocates context budgets to agents:

### Pre-Allocation

Before starting workflow:
```bash
./scripts/context-manager.sh budget
```

```
Pool           Used    Soft    Status
─────────────────────────────────────
reserved       28000   30000   OK
learnings      15000   20000   OK
backlog        8000    15000   OK
plans          0       30000   OK
context7       12000   25000   OK
working        0       30000   OK
─────────────────────────────────────
TOTAL          63000   150000  OK (42%)
```

### During Execution

Monitor for pressure:
- **Normal**: Continue normally
- **Warning (80%)**: Consider optimization
- **Critical (95%)**: Force optimization before continuing

### Optimization Triggers

When context pressure is critical:
1. Summarize old learnings (Tier 2)
2. Archive very old entries (Tier 3)
3. Clear unused Context7 docs
4. Prune completed task plans

## Standard Build Workflow (Implicit)

```
┌─────────────────────────────────────────────────────────────────────┐
│                   /build "Add OAuth authentication"                  │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │      ORCHESTRATOR           │
                    │  ┌─────────────────────┐   │
                    │  │ 1. Initialize       │   │
                    │  │    session          │   │
                    │  └──────────┬──────────┘   │
                    │             │               │
                    │  ┌──────────▼──────────┐   │
                    │  │ 2. Analyze goal     │   │
                    │  │    → Complex        │   │
                    │  │    → Needs planning │   │
                    │  └──────────┬──────────┘   │
                    │             │               │
                    │  ┌──────────▼──────────┐   │
                    │  │ 3. Allocate context │   │
                    │  │    budgets          │   │
                    │  └──────────┬──────────┘   │
                    └─────────────┼───────────────┘
                                  │
                    ┌─────────────▼───────────────┐
                    │         PLANNER              │
                    │  ┌─────────────────────┐    │
                    │  │ Question loop       │    │
                    │  │ (max 5 rounds)      │    │
                    │  └──────────┬──────────┘    │
                    │  ┌──────────▼──────────┐    │
                    │  │ Plan construction   │    │
                    │  └──────────┬──────────┘    │
                    │             │ plan.json     │
                    └─────────────┼───────────────┘
                                  │
                    ┌─────────────▼───────────────┐
                    │      ORCHESTRATOR           │
                    │  ┌─────────────────────┐   │
                    │  │ Evaluate confidence │   │
                    │  │ 85% → Proceed       │   │
                    │  └──────────┬──────────┘   │
                    │  ┌──────────▼──────────┐   │
                    │  │ Handoff context     │   │
                    │  │ to Builder          │   │
                    │  └──────────┬──────────┘   │
                    └─────────────┼───────────────┘
                                  │
                    ┌─────────────▼───────────────┐
                    │         BUILDER              │
                    │  ┌─────────────────────┐    │
                    │  │ Execute loop        │    │
                    │  │ (max 5 per step)    │    │
                    │  └──────────┬──────────┘    │
                    │  ┌──────────▼──────────┐    │
                    │  │ Quality gates       │    │
                    │  └──────────┬──────────┘    │
                    │             │ result        │
                    └─────────────┼───────────────┘
                                  │
                    ┌─────────────▼───────────────┐
                    │      ORCHESTRATOR           │
                    │  ┌─────────────────────┐   │
                    │  │ Finalize            │   │
                    │  │ - Capture learnings │   │
                    │  │ - Update backlog    │   │
                    │  │ - Clean up session  │   │
                    │  └─────────────────────┘   │
                    └─────────────────────────────┘
```

## Best Practices

### 1. Transparent by Default
Users should see a seamless experience. Hide orchestration complexity unless explicitly requested.

### 2. Fail Gracefully
Always save state before any failure. Enable resume.

### 3. Preserve Context
Handoffs must include all context needed for the receiving agent.

### 4. Recover Before Escalating
Try retry and replan before asking user for help.

### 5. Track Everything
Full audit trail enables debugging and improvement.

## Troubleshooting

### "Agent handoff lost context"
- Check handoff record in orchestration state
- Verify context was serialized correctly
- Manually pass missing context on resume

### "Infinite retry loop"
- Check if same error repeating
- Force escalation after pattern detected
- Review replan strategy

### "Orchestration state corrupted"
- List checkpoints: `orchestrator.sh status`
- Resume from last good checkpoint
- Worst case: clean up and restart

---

*"The orchestra plays as one. Each instrument, perfectly timed."*
