---
name: build
description: Execute approved plans through iterative build loop with quality gates and learning capture
arguments:
  - name: target
    description: "Task ID, Feature ID, Epic ID, or omit for next priority task from backlog"
    required: false
triggers:
  - "/build"
  - "/b"
orchestration:
  mode: none
  requires_plan: true
---

# STUDIO Build Command

The `/build` command executes **approved plans** through an iterative build loop that validates each step, retries on failure, runs quality gates, and captures learnings.

## Plan-First Workflow

**IMPORTANT:** The `/build` command requires an existing plan. It does NOT accept raw goal strings.

To build a new feature:

```bash
# Step 1: Create a plan (asks questions, gathers requirements)
/plan "Add user authentication"

# Step 2: Review the plan, answer questions, approve

# Step 3: Execute the approved plan
/build task_xxx
```

### Why Plan-First?

- **No assumptions** — Questions ensure requirements are clear before coding
- **User control** — You review and approve the plan before execution
- **Better outcomes** — Plans with full context produce higher quality code
- **Recoverability** — Approved plans can be re-executed if interrupted

### Command Options

| Command | Action |
|---------|--------------|
| `/build` | Select highest-priority task from backlog |
| `/build task_xxx` | Execute specific task's plan |
| `/build T7` | Execute by short ID |
| `/build F3` | Execute all tasks in feature |
| `/build E1` | Execute all tasks in epic |

### Raw Goals Not Accepted

```bash
# ❌ This will NOT work:
/build "Add user auth"

# ✅ Do this instead:
/plan "Add user auth"   # Creates plan, asks questions
/build task_xxx         # Executes the approved plan
```

## Workflow Phases

```
/build [target]
    -> PHASE 1: Task Selection (next priority or specified)
    -> PHASE 2: Iterative Build Loop (execute -> validate -> fix -> repeat)
    -> PHASE 3: Quality Gates (lint, typecheck, tests, security)
    -> PHASE 4: Learn (capture good/bad/patterns -> studio/learnings/)
    -> Output: Updated backlog, learnings captured
```

## Phase 1: Task Selection

### Auto-Select Next Task

When run without arguments:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header builder
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent builder "Selecting next task..."
```

1. Read `.studio/backlog.json` (if exists)
2. Find tasks with status `PENDING` and no blockers
3. Score by priority and select highest
4. If no backlog, look in `.studio/tasks/` for plans

### Specify Target

```bash
/build                  # Auto-select next priority task
/build task_20260202... # Build specific task
/build T7               # Build by short ID
/build F3               # Build all tasks in feature
/build E1               # Build all tasks in epic
```

## Phase 2: Iterative Build Loop (Ralph-Wiggum Pattern)

The core innovation: execute, validate, fix, repeat.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase building
```

### For Each Step

```
for each step in plan.steps:
    for attempt in 1..5:
        execute(step.action)
        result = validate(step.success_criteria)
        if result.passed:
            break
        else:
            analyze_error(result)
            apply_fix()
            # retry
```

### Step Execution

1. **Announce Step**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" step_header [n] [total] "[step.name]"
   ```

2. **Execute Action**
   - Read the step's action description
   - Perform the required tool calls (Write, Edit, Bash, etc.)

3. **Validate**
   Run each success criterion's verification:

   | Type | Validation |
   |------|------------|
   | `command` | Run command, check exit code 0 |
   | `file_exists` | Check path exists |
   | `file_contains` | Grep for pattern |
   | `test_passes` | Run test command |

4. **On Failure: Analyze and Fix**
   - Read the error output
   - Check `retry_behavior.fix_hints` for guidance
   - Apply fix and retry (up to `max_attempts`)

5. **On Success: Continue**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Step [n] complete"
   ```

### Acceptance Criteria Loop

After all steps complete, verify acceptance criteria:

```
for each criterion in plan.acceptance_criteria:
    result = verify(criterion)
    if not result.passed and criterion.priority == "must":
        iterate_and_fix()
```

### Playwright MCP Integration (for UI criteria)

For acceptance criteria with `type: "playwright"`:

1. **Navigate**: `playwright_navigate(url)`
2. **Perform Actions**:
   - `playwright_click(selector)`
   - `playwright_fill(selector, value)`
   - `playwright_check(selector)`
3. **Assert**:
   - Check element visibility
   - Check text content
   - Check URL
4. **Screenshot**: `playwright_screenshot()` for evidence

Example flow:
```
AC-2: Error messages display inline
-> playwright_navigate("http://localhost:3000/register")
-> playwright_fill("#email", "invalid")
-> playwright_click("button[type=submit]")
-> Assert: .error-message is visible
-> playwright_screenshot() for evidence
```

## Phase 3: Quality Gates

After all acceptance criteria pass, run quality gates:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase quality-gates
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent builder "Running quality gates..."
```

### Gate Sequence

1. **Lint**
   ```bash
   npm run lint
   # or detected linter
   ```

2. **Typecheck**
   ```bash
   npx tsc --noEmit
   ```

3. **Unit Tests**
   ```bash
   npm test
   ```

4. **Security**
   ```bash
   npm audit --audit-level=high
   ```

### Gate Results

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Lint: PASS"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Typecheck: PASS"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Tests: PASS (24 tests)"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status warning "Security: 2 moderate vulnerabilities"
```

If a gate fails, attempt to fix and re-run (lint fixes, type errors, etc.).

## Phase 4: Learn

**After build completes, capture learnings.**

This phase is triggered by the SubagentStop hook but can also run manually.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase learn
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent builder "Capturing learnings from this build..."
```

### 4.1 Summarize What Worked

- Patterns that were effective
- Approaches that succeeded on first try
- Code that was clean and maintainable

### 4.2 Document Problems and Solutions

- Errors that required fixes
- Unexpected issues and resolutions
- Retry attempts and what finally worked

### 4.3 Note New Patterns

- Novel approaches discovered
- Reusable code structures
- Integration techniques

### 4.4 Ask User for Domain

Prompt the user:
```
Where should this learning be saved?
- global (project-wide)
- frontend (UI/components)
- backend (API/services)
- testing (test strategies)
- security (security patterns)
- performance (optimizations)
- integration:<name> (e.g., integration:nextjs)
```

### 4.5 Write to Learnings File

Write to `studio/learnings/{domain}.md`:

```markdown
## 2026-02-02: Form Validation Pattern

**Context:** Building user registration (task_20260202_143052)

**What Worked:**
- Zod + react-hook-form for client-side validation
- Inline error display with immediate feedback

**Problems Solved:**
- Problem: Form submission not showing errors
  Solution: Added `mode: "onBlur"` to react-hook-form config

**Pattern:**
```typescript
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
});

const form = useForm({
  resolver: zodResolver(schema),
  mode: "onBlur"
});
```
```

## Build States

| State | Description |
|-------|-------------|
| `BUILDING` | Executing steps |
| `VALIDATING` | Running acceptance criteria |
| `QUALITY_GATES` | Running quality checks |
| `LEARNING` | Capturing learnings |
| `COMPLETE` | All done |
| `BLOCKED` | Gate failed, needs fix |
| `HALTED` | Max retries exceeded |

## Output Files

### Manifest Update

Update `.studio/tasks/{task_id}/manifest.json`:

```json
{
  "task_id": "task_20260202_143052",
  "status": "COMPLETE",
  "started_at": "...",
  "completed_at": "...",
  "steps_completed": 8,
  "acceptance_criteria_passed": 6,
  "quality_gates": {
    "lint": "PASS",
    "typecheck": "PASS",
    "test": "PASS",
    "security": "WARN"
  },
  "learnings_captured": "frontend.md"
}
```

### Backlog Update

If using backlog, update task status:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" update-status T7 COMPLETE "Build successful"
```

## Example Session

```
User: /build

Builder: Selecting next task...
         Found: task_20260202_143052 - User registration with email verification
         Priority: HIGH (score: 92)

         PHASE 2: Building

         [Step 1/8] Create validation schema
         -> Writing src/schemas/auth.ts
         -> Validating... PASS

         [Step 2/8] Create registration API
         -> Writing src/api/auth/register.ts
         -> Validating... FAIL (import error)
         -> Applying fix: Check bcrypt import
         -> Retrying (2/5)...
         -> Validating... PASS

         [Step 3/8] Create email service
         ...

         PHASE 3: Acceptance Criteria

         [AC-1] Registration form renders... PASS
         [AC-2] Validation errors show inline...
         -> playwright_navigate("http://localhost:3000/register")
         -> playwright_fill("#email", "invalid")
         -> playwright_click("button[type=submit]")
         -> Asserting .error-message visible... PASS
         [AC-3] Email sent on submit... PASS
         ...

         PHASE 4: Quality Gates

         Lint: PASS
         Typecheck: PASS
         Tests: PASS (24 tests)
         Security: PASS

         PHASE 5: Learn

         Where should I save this learning?
         1. global
         2. frontend
         3. backend

User: 2

Builder: Learning captured to studio/learnings/frontend.md

         BUILD COMPLETE

         Summary:
         - Task: task_20260202_143052
         - Steps: 8/8 complete
         - Acceptance: 6/6 passed
         - Quality: All gates passed
         - Learning: Saved to frontend.md

         Next ready task: task_20260202_150000
         Run /build to continue
```

## Integration with /plan

The build command reads plans created by `/plan`:

1. Load plan from `.studio/tasks/{task_id}/plan.json`
2. Execute steps with iterative validation
3. Verify acceptance criteria
4. Run quality gates
5. Capture learnings

## Integration with /orchestrate

For explicit control over orchestration:

```bash
/orchestrate build "goal"     # Full visibility mode
/orchestrate status           # Check orchestration state
/orchestrate resume           # Resume interrupted work
```

## Implicit Orchestration Details

When `/build "goal"` triggers orchestration:

### 1. Goal Analysis (via PreCommand hook)

```bash
scripts/orchestrator.sh init "$GOAL" implicit
scripts/orchestrator.sh route
```

The orchestrator analyzes:
- Goal complexity (simple fix vs new feature)
- Whether a plan exists
- Required agents
- Returns routing confidence score

### 2. Routing Decision

| Signal | Route | Confidence |
|--------|-------|------------|
| "fix", "bug", "typo" | Builder only | 0.7 |
| "add", "create", "implement" | Planner → Builder | 0.85 |
| "refactor", "reorganize" | Planner → Builder | 0.9 |
| Existing plan file | Builder only | 1.0 |

### 3. Skill Detection (via SubagentStart hook)

Before each agent starts:
```bash
scripts/skills.sh detect "$GOAL"   # Returns matching skills with scores
scripts/skills.sh inject <skill>   # Gets injection content
```

Skills provide domain-specific guidance:
- Security skill: Auth patterns, input validation, OWASP checks
- Frontend skill: Component patterns, accessibility, responsive design
- Backend skill: API design, error handling, database patterns
- Testing skill: Test strategies, coverage requirements

### 4. Agent Handoffs

Context is passed between agents via orchestrator:

```bash
# After Planner completes
scripts/orchestrator.sh handoff planner builder '{"task_id":"task_xxx","plan_path":".studio/tasks/task_xxx/plan.json","skills":["security","backend"]}'

# Builder retrieves handoff
scripts/orchestrator.sh get-handoff builder  # Returns the context JSON
```

### 5. Failure Recovery

On agent failure, orchestrator determines action:
```bash
scripts/orchestrator.sh agent-fail builder "Error message"
scripts/orchestrator.sh recover builder
```

Recovery thresholds:
| Failures | Action | Description |
|----------|--------|-------------|
| < 3 | retry | Retry same step with fixes |
| 3-4 | replan | Send back to Planner for revision |
| 5+ | escalate | Ask user for help |

### 6. Auto-Checkpoints (via SubagentStop hook)

After each agent completes:
```bash
scripts/orchestrator.sh agent-complete <agent>
scripts/orchestrator.sh checkpoint '<agent>_complete'
```

State saved to:
```
.studio/orchestration/orch_xxx/
├── state.json            # Current state
├── cp_xxx.json           # Checkpoint snapshots
└── (session continues)
```

### 7. Session Resume (via SessionStart hook)

On session start, checks for interrupted orchestration:
- If `status: "paused"` → Prompt to resume
- If `status: "recovering"` → Show last failure, offer recovery
- If `status: "executing"` → Offer to resume from checkpoint

Resume:
```bash
scripts/orchestrator.sh resume
```

## Agent Definition

This command invokes the **Builder** agent defined in `agents/builder.yaml`.

When orchestration is active, it also coordinates with:
- **Orchestrator** agent (`agents/orchestrator.yaml`)
- **Planner** agent (`agents/planner.yaml`) if planning needed
