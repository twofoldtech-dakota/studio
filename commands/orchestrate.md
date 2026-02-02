---
name: orchestrate
description: Explicitly coordinate multi-agent workflows with visibility and control
arguments:
  - name: action
    description: "Action: build, multi-task, status, resume"
    required: false
  - name: target
    description: "Target goal, task ID, or checkpoint ID"
    required: false
triggers:
  - "/orchestrate"
---

# STUDIO Orchestrate Command

The `/orchestrate` command provides explicit control over multi-agent workflows. Unlike the implicit orchestration in `/build`, this command gives visibility into routing decisions, agent states, and recovery options.

## Quick Reference

```bash
/orchestrate                    # Show current orchestration status
/orchestrate build "goal"       # Start orchestrated build with visibility
/orchestrate multi-task         # Execute multiple tasks from backlog
/orchestrate status             # Detailed orchestration state
/orchestrate resume             # Resume paused orchestration
/orchestrate resume <checkpoint># Resume from specific checkpoint
```

## Subcommands

### `/orchestrate build`

Start a build with full orchestration visibility.

```bash
/orchestrate build "Add user authentication with OAuth"
```

**Output:**
```
════════════════════════════════════════════════════════════════════════════════
                              ORCHESTRATION
════════════════════════════════════════════════════════════════════════════════

[Orchestrator] Initializing session: orch_20260202_143052_a1b2
[Orchestrator] Analyzing goal...

┌─────────────────────────────────────────────────────────────────┐
│  ROUTING DECISION                                                │
├─────────────────────────────────────────────────────────────────┤
│  Goal:       Add user authentication with OAuth                 │
│  Complexity: HIGH                                               │
│  Workflow:   plan_then_build                                    │
│  Agents:     Planner → Builder                                  │
│  Confidence: 85%                                                │
└─────────────────────────────────────────────────────────────────┘

Proceed with this workflow? [y/n/custom]
```

After confirmation, shows progress:
```
[Orchestrator] Starting Planner agent...

════════════════════════════════════════════════════════════════════════════════
                              THE PLANNER
════════════════════════════════════════════════════════════════════════════════

[Planner] Phase 1: Context Gathering
...

[Orchestrator] Planner complete. Plan created: bp_20260202_143052_a1b2
[Orchestrator] Confidence score: 87%
[Orchestrator] Checkpointing: planning_complete

[Orchestrator] Handing off to Builder...
[Orchestrator] Context passed: task_id, plan_id, learnings

════════════════════════════════════════════════════════════════════════════════
                              THE BUILDER
════════════════════════════════════════════════════════════════════════════════

[Builder] Phase 2: Building
...
```

### `/orchestrate multi-task`

Execute multiple tasks from the backlog in sequence.

```bash
/orchestrate multi-task
```

**Output:**
```
[Orchestrator] Scanning backlog for ready tasks...

┌─────────────────────────────────────────────────────────────────┐
│  MULTI-TASK EXECUTION                                           │
├─────────────────────────────────────────────────────────────────┤
│  Ready tasks: 3                                                 │
│                                                                 │
│  1. T7  - Add login form         Priority: 95  Est: 2h        │
│  2. T8  - Add logout button      Priority: 87  Est: 1h        │
│  3. T12 - Fix validation bug     Priority: 82  Est: 30m       │
│                                                                 │
│  Total estimated: 3.5 hours                                    │
└─────────────────────────────────────────────────────────────────┘

Execute all tasks in order? [y/n/select]
```

With `select`, you can choose specific tasks:
```
Enter task numbers to execute (comma-separated): 1,3

[Orchestrator] Queuing tasks: T7, T12
[Orchestrator] Starting T7: Add login form
...
```

### `/orchestrate status`

Show detailed orchestration state.

```bash
/orchestrate status
```

**Output:**
```
═══════════════════════════════════════════════════════════════
            ORCHESTRATION STATUS
═══════════════════════════════════════════════════════════════

Session:  orch_20260202_143052_a1b2
Mode:     explicit
Status:   executing
Goal:     Add user authentication with OAuth...

Workflow: plan_then_build
Confidence: 85%

Agent Sequence:
  [✓] planner
  [⟳] builder
  [○] (pending none)

Context Budget:
  Pool         Used     Soft     Status
  ─────────────────────────────────────
  reserved     28000    30000    OK
  learnings    15000    20000    OK
  plans        22000    30000    OK
  working      18000    30000    OK
  ─────────────────────────────────────
  TOTAL        83000    150000   OK (55%)

Checkpoints: 1
  - planning_complete (cp_1706789123)

Failures: 0
```

### `/orchestrate resume`

Resume a paused or failed orchestration.

```bash
/orchestrate resume                    # Resume from latest checkpoint
/orchestrate resume cp_1706789123      # Resume from specific checkpoint
```

**Output:**
```
[Orchestrator] Loading checkpoint: cp_1706789123 (planning_complete)

┌─────────────────────────────────────────────────────────────────┐
│  RESUME FROM CHECKPOINT                                         │
├─────────────────────────────────────────────────────────────────┤
│  Checkpoint: planning_complete                                  │
│  Saved at:   2026-02-02T14:35:23Z                              │
│  After:      Planner agent                                      │
│                                                                 │
│  Completed:                                                     │
│    ✓ Planner - Plan created (bp_xxx)                           │
│                                                                 │
│  Remaining:                                                     │
│    ○ Builder - Execute plan                                     │
└─────────────────────────────────────────────────────────────────┘

Resume from this checkpoint? [y/n]
```

## Orchestration Modes

### Explicit vs Implicit

| Aspect | Explicit (`/orchestrate`) | Implicit (`/build`) |
|--------|---------------------------|---------------------|
| Routing visibility | Shown, confirmable | Hidden |
| Agent transitions | Announced | Seamless |
| Checkpoints | Listed | Silent |
| Failures | Detailed options | Auto-recover |
| Best for | Control, debugging | Normal use |

### When to Use Explicit Mode

1. **Complex goals** - When you want to verify routing
2. **Debugging** - When previous builds failed
3. **Learning** - To understand how STUDIO works
4. **Multi-task** - When executing batches
5. **Resume** - When continuing interrupted work

## Workflow Details

### Standard Build Workflow

```
/orchestrate build "goal"
│
├─ Initialize session
├─ Analyze goal → Determine workflow
├─ Confirm routing with user
│
├─ [If plan_then_build]
│   ├─ Start Planner
│   ├─ Questioning loop
│   ├─ Plan construction
│   ├─ Checkpoint: planning_complete
│   └─ Evaluate confidence
│
├─ Handoff to Builder
│   ├─ Start Builder
│   ├─ Execute loop
│   ├─ Quality gates
│   └─ Learn phase
│
├─ Handle outcome
│   ├─ SUCCESS → Finalize
│   ├─ RECOVERABLE → Retry/Replan
│   └─ UNRECOVERABLE → Escalate
│
└─ Finalize
    ├─ Update backlog
    ├─ Save learnings
    └─ Clean up session
```

### Failure Recovery

When a failure occurs:

```
[Orchestrator] Builder failed at step 3

┌─────────────────────────────────────────────────────────────────┐
│  FAILURE RECOVERY                                               │
├─────────────────────────────────────────────────────────────────┤
│  Agent:    Builder                                              │
│  Step:     3/8 - Create OAuth callback handler                  │
│  Attempts: 5/5                                                  │
│                                                                 │
│  Error:                                                         │
│  Cannot resolve OAuth callback URL - missing OAUTH_CALLBACK_URL │
│  environment variable                                           │
│                                                                 │
│  Recovery options:                                              │
│  [1] Retry with fix - Add env variable and retry                │
│  [2] Replan - Go back to Planner with new context              │
│  [3] Skip - Skip this step (if non-critical)                   │
│  [4] Abort - Stop orchestration, save checkpoint               │
└─────────────────────────────────────────────────────────────────┘

Select option [1-4]:
```

## Context Budget Display

During orchestration, context usage is tracked:

```
[Orchestrator] Context budget check:

  Pool         Used     Soft     Status
  ─────────────────────────────────────────
  learnings    18000    20000    ⚠ WARNING
  plans        28000    30000    ⚠ WARNING
  working      35000    30000    ✗ EXCEEDED
  ─────────────────────────────────────────

[Orchestrator] Working pool exceeded. Triggering optimization...
[Orchestrator] Summarized 5 learnings entries (saved 8000 tokens)
[Orchestrator] Continuing with optimized context
```

## Example Sessions

### Example 1: Simple Feature

```
User: /orchestrate build "Add dark mode toggle"

[Orchestrator] Analyzing goal...

Routing Decision:
  Goal:       Add dark mode toggle
  Complexity: MEDIUM
  Workflow:   plan_then_build
  Confidence: 90%

Proceed? y

[Planner] Starting context gathering...
[Planner] Found 2 relevant learnings in frontend domain
[Planner] Questions:
  1. Where should the toggle appear? (header/settings/both)
  2. Should it persist across sessions?

User: Header. Yes, persist to localStorage.

[Planner] Creating plan...
[Planner] Plan created: 4 steps, 3 acceptance criteria
[Orchestrator] Checkpoint: planning_complete
[Orchestrator] Handing off to Builder...

[Builder] Step 1/4: Create theme context
[Builder] ✓ Step 1 complete
[Builder] Step 2/4: Add toggle component
[Builder] ✓ Step 2 complete
...
[Builder] Quality gates: All passed

[Orchestrator] BUILD COMPLETE
  Task: task_20260202_143052
  Steps: 4/4
  Time: 8 minutes
```

### Example 2: Failure Recovery

```
User: /orchestrate build "Integrate Stripe payments"

[Orchestrator] Routing: plan_then_build (confidence: 82%)
Proceed? y

[Planner] ...plan created...
[Orchestrator] Handing off to Builder...

[Builder] Step 1/6: Install Stripe SDK ✓
[Builder] Step 2/6: Create payment service ✓
[Builder] Step 3/6: Add checkout endpoint
[Builder] ✗ Validation failed: Missing STRIPE_SECRET_KEY
[Builder] Retry 1/5: Checking environment...
[Builder] ✗ Still failing
...
[Builder] Retry 5/5: Failed

[Orchestrator] Builder exceeded retries

Recovery Options:
[1] Retry with fix
[2] Replan
[3] Skip
[4] Abort

User: 1

[Orchestrator] What fix should be applied?
User: Add .env.local with test Stripe key

[Builder] Applying fix...
[Builder] Retrying step 3...
[Builder] ✓ Step 3 complete
...
[Builder] BUILD COMPLETE
```

## Integration with Other Commands

### From `/build`

The regular `/build` command uses implicit orchestration. Use `/orchestrate build` when you need visibility.

### From `/project:run`

Multi-task execution is available via:
```
/project:run           # Uses implicit orchestration
/orchestrate multi-task # Uses explicit orchestration
```

### With Backlog

Orchestration reads from `.studio/backlog.json` for task priorities and dependencies.

## Technical Details

### State Storage

Orchestration state is stored in:
```
.studio/orchestration/
└── orch_YYYYMMDD_HHMMSS_XXXX/
    ├── state.json          # Current state
    ├── cp_timestamp.json   # Checkpoints
    └── ...
```

### Scripts

The orchestrator uses these utilities:
```bash
./scripts/orchestrator.sh init "goal"
./scripts/orchestrator.sh route
./scripts/orchestrator.sh agent-start planner
./scripts/orchestrator.sh agent-complete planner
./scripts/orchestrator.sh checkpoint "name"
./scripts/orchestrator.sh resume
./scripts/orchestrator.sh status
```

---

*"Control the workflow. See everything. Miss nothing."*
