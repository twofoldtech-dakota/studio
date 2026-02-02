---
name: building
description: Plan-and-Execute methodology for adaptive execution with replanning
triggers:
  - "execute"
  - "build"
  - "implement"
  - "build"
  - "plan-and-execute"
  - "replan"
loop_config: data/loop-configs/builder.yaml
---

# Building Skill: Plan-and-Execute Methodology

This skill teaches the **Plan-and-Execute** methodology for executing plans while adapting to reality. It draws from research including "ReAct: Synergizing Reasoning and Acting in Language Models" (Yao et al., 2022) and LangGraph execution patterns.

## Loop Configuration

The builder uses the universal loop system defined in `data/loop-configs/builder.yaml`:

```yaml
loop_type: execute-validate-fix
max_iterations: 5
trigger: each_step
phases: [execute, validate, analyze, fix, complete, escalate]
```

**Key Loop Phases:**
- **ATTEMPT (execute)**: Perform the step action
- **OBSERVE (validate)**: Run success criteria verification
- **EVALUATE (analyze)**: Determine cause of failure
- **RETRY (fix)**: Apply fix and retry
- **NEXT (complete)**: Proceed to next step
- **ESCALATE**: Max retries exceeded

## The Core Insight

Plans are hypotheses about how to achieve a goal. Reality is the test. The Plan-and-Execute methodology acknowledges that no plan survives contact with reality unchanged, and builds adaptation into the execution process itself.

```
Traditional Execution:       Plan-and-Execute:
──────────────────────       ─────────────────

Plan → Execute All → Done    Plan → Execute Step → Observe → Decide
       (hope it works)              ↓                         ↓
                               Continue ←── Adapt ←── Replan
                                  ↓
                                Done
```

## The Execute-Observe-Decide Loop

Every step follows this pattern:

```
┌─────────────────────────────────────────────────────────┐
│                 THE BUILDING LOOP                        │
│                                                         │
│    ┌─────────┐                                          │
│    │ EXECUTE │  Perform the action                      │
│    └────┬────┘                                          │
│         ↓                                               │
│    ┌─────────┐                                          │
│    │ OBSERVE │  Capture what happened                   │
│    └────┬────┘                                          │
│         ↓                                               │
│    ┌─────────┐                                          │
│    │ DECIDE  │  Continue, Replan, or Halt               │
│    └────┬────┘                                          │
│         │                                               │
│    ┌────┴────┬─────────────┬─────────────┐             │
│    ↓         ↓             ↓             ↓             │
│ Continue   Replan        Retry         Halt            │
│    ↓         ↓             ↓             ↓             │
│ Next Step  Modify Plan  Same Step    Stop Work         │
│    ↓         ↓             ↓                           │
│    └─────────┴─────────────┘                           │
│         ↓                                               │
│    Loop until complete                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Execute Phase

### Execution Principles

1. **Do exactly what the step says** - The plan was designed carefully
2. **Use the right tools** - Match tool to task
3. **Capture everything** - Outputs, artifacts, side effects
4. **Stay focused** - One step at a time

### Tool Selection Guide

| Task | Primary Tool | Fallback |
|------|-------------|----------|
| Read file | Read | Bash cat |
| Create file | Write | - |
| Edit file | Edit | Write (full rewrite) |
| Find files | Glob | Bash find |
| Search content | Grep | Bash grep |
| Run command | Bash | - |
| Complex task | Task (subagent) | - |

### Execution Recording

Every execution must be recorded:

```yaml
execution_record:
  step_id: "step_1"
  started_at: "2025-01-15T14:32:00Z"
  completed_at: "2025-01-15T14:33:15Z"
  status: "success"

  action_taken: |
    Created src/schemas/auth.ts with Zod validation schema.
    Defined registerSchema with email, password, and name fields.

  tool_calls:
    - tool: "Write"
      path: "src/schemas/auth.ts"
      result: "success"

  outputs_produced:
    - name: "registerSchema"
      type: "file"
      location: "src/schemas/auth.ts"

  artifacts:
    - path: "src/schemas/auth.ts"
      action: "created"
      size_bytes: 1247

  observations:
    - "Used stricter email validation than minimum required"
```

## Observe Phase

### What to Observe

After execution, observe:

1. **Success or Failure**: Did the action complete?
2. **Outputs**: What was produced?
3. **Side Effects**: What else changed?
4. **Anomalies**: Anything unexpected?
5. **State**: What is the current state?

### Observation Categories

**Expected Success**
```
Action completed as planned.
Outputs match expectations.
Ready to continue.
```

**Unexpected Success**
```
Action completed, but:
- Produced different output than expected
- Took longer than anticipated
- Had side effects
Assess if modifications needed.
```

**Expected Failure**
```
Action failed in anticipated way.
Failure mode was documented in plan.
Recovery plan exists.
Execute recovery.
```

**Unexpected Failure**
```
Action failed unexpectedly.
No pre-planned recovery.
Need to assess and replan.
```

### Verifying Success Criteria

For each criterion in the step:

```
Criterion: "File exists at src/schemas/auth.ts"
Method: test -f src/schemas/auth.ts
Result: EXISTS ✓

Criterion: "Schema exports registerSchema"
Method: grep "export.*registerSchema" src/schemas/auth.ts
Result: FOUND ✓

Criterion: "Schema validates correct inputs"
Method: Run unit test
Result: PASS ✓
```

## Decide Phase

Based on observations, make one of these decisions:

### Decision: Continue

**When**: Step succeeded, all criteria met, no issues
**Action**: Move to next step
**Record**: Mark step complete, proceed

```
Step 1: ✓ Complete
→ Proceeding to Step 2
```

### Decision: Retry

**When**: Transient failure, might succeed on retry
**Action**: Execute same step again (with limit)
**Record**: Log retry attempt

```
Step 3: Failed (network timeout)
→ Retry 1/3
→ Waiting 2 seconds...
→ Retrying Step 3
```

Retry limits:
- Maximum 3 retries per step
- Exponential backoff (2s, 4s, 8s)
- After max retries, escalate to replan

### Decision: Replan

**When**: Step failed but work can continue with modification
**Action**: Modify plan and continue
**Record**: Log replan decision and rationale

```
Step 3: Failed (missing dependency)
→ Replan triggered
→ Adding prerequisite step
→ Executing new step
→ Resuming original flow
```

### Decision: Halt

**When**: Critical failure, cannot continue
**Action**: Save state, report status, stop
**Record**: Log halt reason, save checkpoint

```
Step 5: CRITICAL FAILURE
→ Database connection unavailable
→ No recovery path
→ Halting at checkpoint "Core logic complete"
→ State saved for resume
```

## Replanning Strategies

When replanning is needed, choose the appropriate strategy:

### Strategy 1: Local Repair

**Use when**: Step failed due to minor fixable issue
**Action**: Fix the specific problem and retry

```
Problem: Syntax error in generated code
Fix: Correct the syntax
Retry: Execute step again

replan:
  strategy: "local_repair"
  problem: "Missing semicolon on line 15"
  fix: "Add semicolon"
  action: "Retry step with corrected output"
```

### Strategy 2: Substitution

**Use when**: Planned approach doesn't work, alternative exists
**Action**: Replace approach with equivalent alternative

```
Problem: npm install fails
Alternative: yarn install
Outcome: Same result, different method

replan:
  strategy: "substitution"
  original: "npm install bcrypt"
  substitute: "yarn add bcrypt"
  rationale: "npm registry timeout, yarn cache available"
```

### Strategy 3: Add Steps

**Use when**: Missing prerequisite discovered during execution
**Action**: Insert new steps before current step

```
Problem: bcrypt package not installed
Solution: Add installation step before use

replan:
  strategy: "add_steps"
  new_step:
    id: "step_2a"
    name: "Install bcrypt dependency"
    action: "npm install bcrypt @types/bcrypt"
    insert_before: "step_3"
```

### Strategy 4: Skip

**Use when**: Step is non-critical and blocked
**Action**: Skip step, document why, continue

```
Problem: Optional optimization step requires unavailable tool
Decision: Skip optimization, proceed without it

replan:
  strategy: "skip"
  skipped_step: "step_7"
  reason: "Performance profiler not available"
  impact: "Optimization skipped, functionality unaffected"
```

### Strategy 5: Alternative Path

**Use when**: Current approach fundamentally blocked
**Action**: Completely different approach to same goal

```
Problem: REST API approach blocked by firewall
Alternative: Use WebSocket approach instead

replan:
  strategy: "alternative_path"
  original_approach: "REST endpoints"
  new_approach: "WebSocket messages"
  rationale: "Firewall blocks REST, WebSocket permitted"
  steps_affected: ["step_4", "step_5", "step_6"]
```

## Execution State Management

Maintain state throughout execution:

```yaml
build_state:
  plan_id: "bp_xxx"
  task_id: "task_xxx"
  status: "building"

  current_step: "step_3"

  steps:
    step_1: "completed"
    step_2: "completed"
    step_3: "in_progress"
    step_4: "pending"
    step_5: "pending"

  outputs:
    registerSchema:
      from_step: "step_1"
      location: "src/schemas/auth.ts"
    authService:
      from_step: "step_2"
      location: "src/services/auth.ts"

  artifacts:
    - path: "src/schemas/auth.ts"
      created_at: "2025-01-15T14:32:00Z"
    - path: "src/services/auth.ts"
      created_at: "2025-01-15T14:34:00Z"

  replans: []
  retries: {}
  checkpoints_reached: ["after_step_2"]
```

## Loop State Persistence

The loop state is automatically saved to enable recovery:

```yaml
# .studio/tasks/{task_id}/loop_state.json
loop_state:
  loop_id: "loop_step_3_1706789123"
  config_name: "builder-execute-validate"
  current_iteration: 2
  current_phase: "fix"
  status: "running"
  phase_history:
    - phase_id: "execute"
      iteration: 1
      outcome: "success"
    - phase_id: "validate"
      iteration: 1
      outcome: "failure"
    - phase_id: "analyze"
      iteration: 1
      outcome: "success"
  accumulated_outputs:
    action_output: "..."
    validation_results: "..."
    error_analysis: "..."
  error_log:
    - iteration: 1
      phase_id: "validate"
      error: "File contains syntax error"
```

### Loop Checkpointing

Checkpoints are saved after each successful step completion:

```bash
# Automatic checkpoint after step completes
"${CLAUDE_PLUGIN_ROOT}/scripts/orchestrator.sh" checkpoint "step_${STEP_NUM}_complete"
```

To resume from a loop checkpoint:
```bash
# Load loop state and continue
cat ".studio/tasks/${TASK_ID}/loop_state.json"
# Resume from last successful iteration
```

## Checkpoint Management

At defined checkpoints:

### Reaching a Checkpoint

```
◆ CHECKPOINT: [name]
──────────────────────────────────────────

Verifying checkpoint conditions:
[✓] Condition 1
[✓] Condition 2
[✓] Condition 3

Checkpoint PASSED

Saving state...
State saved to: studio/tasks/[id]/checkpoint_[name].json
```

### Checkpoint State

```yaml
checkpoint_state:
  checkpoint_name: "Core logic complete"
  reached_at: "2025-01-15T14:36:00Z"
  step_after: "step_3"

  completed_steps: ["step_1", "step_2", "step_3"]
  outputs: {...}
  artifacts: [...]

  can_resume_from: true
  rollback_to_step: "step_1"
```

### Rolling Back to Checkpoint

When later steps fail:

```
Step 5 failed critically.
Rolling back to checkpoint "Core logic complete"

Restoring state from checkpoint...
Completed steps: step_1, step_2, step_3
Next step: step_4

Options:
1. Retry step 4 with different approach
2. Replan steps 4-6
3. Abort task
```

## Error Handling

### Recoverable Errors

Errors that can be handled automatically:

| Error Type | Recovery |
|------------|----------|
| File not found | Check path, search for file |
| Permission denied | Check permissions, use sudo if appropriate |
| Network timeout | Retry with backoff |
| Syntax error | Fix and retry |
| Missing dependency | Install and retry |

### Unrecoverable Errors

Errors that require escalation:

| Error Type | Action |
|------------|--------|
| Critical system failure | Halt, save state |
| Security violation | Halt, report |
| Resource exhausted | Halt, report |
| Fundamental blocker | Halt, recommend replan |

### Error Recording

```yaml
error_record:
  step_id: "step_4"
  error_type: "runtime_error"
  error_message: "Cannot connect to database"
  timestamp: "2025-01-15T14:38:00Z"

  context:
    action_attempted: "Run migration"
    tool_used: "Bash"
    command: "npm run migrate"

  recovery_attempted: true
  recovery_strategy: "retry"
  recovery_successful: false
  retries: 3

  escalation: "halted"
  checkpoint_saved: "after_step_3"
```

## Progress Communication

Keep the user informed throughout:

### Starting a Step

```
● Step 3/6: Create auth controller
  → Creating src/controllers/auth.ts
```

### During Execution

```
  → Implementing register handler
  → Adding error handling
  → Integrating with service
```

### Step Success

```
  → Verifying success criteria:
    [✓] File exists at src/controllers/auth.ts
    [✓] register function handles POST requests
  ✓ Step 3 complete
```

### Step Failure with Recovery

```
  [!] Import path incorrect
  → Analyzing failure...
  → Applying local repair
  → Fixed import path
  → Retrying...
  ✓ Step 3 complete (after repair)
```

### Checkpoint Reached

```
◆ CHECKPOINT: Endpoint operational
  [✓] POST /api/auth/register returns 201 or 4xx
  [✓] No 500 errors on valid input
  → Checkpoint passed, state saved
```

## Best Practices

### 1. Trust the Plan, But Verify

The plan was carefully designed, but reality may differ:
- Execute as planned
- Verify results
- Adapt if needed

### 2. Small Steps, Frequent Checks

Don't batch work:
- Execute one step
- Verify completion
- Then proceed

### 3. Fail Fast, Recover Faster

When something goes wrong:
- Detect quickly
- Assess accurately
- Recover promptly

### 4. Record Everything

Future debugging depends on your records:
- What was attempted
- What happened
- What was decided

### 5. Communicate Continuously

The user should never wonder what's happening:
- Show progress
- Explain issues
- Report outcomes

---

*"The build reveals what the plan cannot predict. Adapt, but never lose sight of the goal." - Building Principle*
