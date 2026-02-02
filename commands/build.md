---
name: build
description: Execute tasks through STUDIO's plan-then-build workflow with smart work selection
arguments:
  - name: target
    description: "Task ID (T1), Feature ID (F1), Epic ID (E1), or goal text"
    required: false
  - name: subcommand
    description: "Optional subcommand: resume, status, abort, list, preview"
    required: false
triggers:
  - "/build"
  - "/build:preview"
  - "/build:interactive"
  - "/build:resume"
  - "/build:status"
  - "/build:abort"
  - "/build:list"
---

# STUDIO Build Command

You are initiating a **STUDIO Build** - an autonomous workflow that transforms goals into verified outcomes through two phases: **Plan** then **Build**.

## Smart Command Parsing

The `/build` command intelligently handles multiple input types:

| Command | Behavior |
|---------|----------|
| `/build` | Execute next highest-priority ready task from backlog |
| `/build T7` | Build specific task T7 |
| `/build F3` | Build all tasks in Feature F3 |
| `/build E1` | Build all tasks in Epic E1 |
| `/build "text"` | Plan text first, add to backlog, then build |
| `/build login` | Fuzzy match "login" to find task/feature |

### ID Resolution

Short IDs are resolved automatically:
- `E1` → `EPIC-001`
- `F3` → `FEAT-003`
- `T7` → `task_20260201_120000`

Fuzzy matching works on names:
- `login` → matches "Feature: Login Flow"
- `auth` → matches "Epic: Authentication"

```bash
# Resolve ID using backlog script
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" resolve-id "T7"
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" resolve-id "login"
```

## Terminal Output

**IMPORTANT**: Use the output.sh script for all formatted terminal output.

```bash
# Display headers
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header build

# Display phase transitions
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase planning
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase building
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase reviewing

# Display agent messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent planner "Analyzing goal..."
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent builder "Executing step 1..."

# Display status messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Step complete"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status error "Step failed"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status warning "Issue detected"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Processing..."

# Display banners
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" banner complete
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" banner failed
```

## Work Selection Algorithm

When `/build` is run without arguments, the system selects the next task using:

```
SCORE = (0.35 × priority) +
        (0.25 × dependency_unlock) +
        (0.20 × business_value) +
        (0.20 × readiness)
```

Where:
- **priority**: User-assigned (1-5, where 1 is highest)
- **dependency_unlock**: How many tasks this unblocks (0-100)
- **business_value**: From parent epic (critical=100, high=75, medium=50, low=25)
- **readiness**: All dependencies satisfied = 100, else 0

```bash
# Get next highest-priority ready task
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" next-task

# Score a specific task
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" score-task T7

# Get all ready tasks
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" ready-tasks
```

## Command Variants

### `/build`
Execute the next highest-priority ready task from the backlog.

```
/build
  │
  ▼
┌─────────────────────────────────────────┐
│  SELECTING NEXT TASK...                 │
│                                         │
│  Ready tasks (deps satisfied):          │
│  1. T8 - Password reset email (score:92)│
│  2. T15 - Add Stripe SDK (score: 78)    │
│  3. T12 - Unit tests (score: 65)        │
│                                         │
│  Executing: T8 - Password reset email   │
│  ───────────────────────────────────    │
│  [Planner phase...]                     │
│  [Builder phase...]                     │
│  ✓ Task complete                        │
│                                         │
│  Next ready: T15 - Add Stripe SDK       │
│  Run /build to continue                 │
└─────────────────────────────────────────┘
```

### `/build <id>`
Build a specific item by ID (task, feature, or epic).

```bash
/build T7   # Build task T7
/build F3   # Build all tasks in Feature F3 (in dependency order)
/build E1   # Build all tasks in Epic E1 (in dependency order)
```

```
/build F3
  │
  ▼
┌─────────────────────────────────────────┐
│  BUILDING FEATURE: F3 - User Profile    │
│                                         │
│  Tasks in this feature:                 │
│  ├── T9 - Profile API endpoint          │
│  ├── T10 - Profile UI component         │
│  └── T11 - Profile tests                │
│                                         │
│  Executing in dependency order...       │
│  [T9] ✓ Complete                        │
│  [T10] ⟳ Building...                    │
└─────────────────────────────────────────┘
```

### `/build "text"`
Plan the text first, add to backlog, then build.

```
/build "Add dark mode toggle"
  │
  ▼
┌─────────────────────────────────────────┐
│  NEW GOAL DETECTED                      │
│                                         │
│  This will:                             │
│  1. Decompose into tasks                │
│  2. Add to backlog under appropriate    │
│     epic/feature (or create new)        │
│  3. Execute the first task              │
│                                         │
│  Decomposing...                         │
│  → Added to: E1/F2 - UI Settings        │
│  → Created: T20 - Dark mode toggle      │
│                                         │
│  Executing T20...                       │
└─────────────────────────────────────────┘
```

### `/build <goal>`
Start a new build with the specified goal (legacy behavior).

### `/build:preview <goal>`
Preview what the build would do without executing. Shows:
- Requirements that would be gathered
- Steps that would be created
- Quality checks that would run

### `/build:interactive <goal>`
Step-by-step build with confirmation at each step.

Sets `STUDIO_INTERACTIVE=true` environment variable, which triggers interactive confirmation hooks.

Before each file change, you'll see:
```
╔══════════════════════════════════════════════════════════════╗
║  INTERACTIVE MODE                                            ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  About to: Write src/schemas/auth.ts                         ║
║                                                              ║
║  Preview:                                                    ║
║  import { z } from 'zod';                                    ║
║  export const registerSchema = z.object({...                 ║
║                                                              ║
║  Options:                                                    ║
║  [y] Execute this change                                     ║
║  [e] Edit first                                              ║
║  [s] Skip this step                                          ║
║  [a] Abort build                                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

### `/build resume [task_id]`
Resume a paused or failed build.

### `/build status [task_id]`
Check the status of a build.

### `/build abort [task_id]`
Cancel an active build.

### `/build list`
List all builds in current project.

## Workflow Phases

### Phase 1: PLAN (The Planner)

The Planner creates an execution-ready plan:

1. **Playbook Load** - Load planning methodology
2. **Context Lock** - Load and embed all Memory rules
3. **Requirements Gathering** - Use team member questions
4. **Plan Construction** - Create steps with validation commands

Output: `studio/projects/[project]/tasks/[task]/plan.json`

### Phase 2: BUILD (The Builder)

The Builder executes the plan exactly as specified:

1. **Plan Load** - Read the execution-ready plan
2. **Execution Loop** - For each step:
   - Execute micro-actions
   - Run validation commands
   - Follow retry behavior on failure
3. **Quality Gate** - Run final validation checks

Output: Working code + `manifest.json` with status

## Execution Protocol

### With Backlog Integration

```
/build
  │
  ├── Backlog exists?
  │   ├── Yes: Get next ready task from backlog
  │   │   └── Execute task (Plan → Build)
  │   │       └── Update task status to COMPLETE
  │   │           └── Show next ready task
  │   └── No: Prompt for goal
  │
  └── Argument provided?
      ├── Looks like ID (E1, F3, T7)?
      │   └── Resolve ID → Execute item(s)
      └── Text goal?
          └── Decompose → Add to backlog → Execute
```

### Full Execution Flow

```
/build "Add user authentication"
         │
         ▼
┌─────────────────────────────────────────┐
│  PHASE 0: BACKLOG INTEGRATION           │
│                                         │
│  1. Check if backlog exists             │
│  2. Decompose goal into tasks           │
│  3. Add to backlog (or create new)      │
│  4. Select first task to execute        │
│                                         │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  PHASE 1: PLAN                          │
│                                         │
│  1. Load playbooks (planning, memory)   │
│  2. Load team (BA, orchestrator, etc.)  │
│  3. Ask requirements questions          │
│  4. Create execution-ready plan         │
│  5. Save plan.json                      │
│                                         │
│  Output: plan.json with embedded        │
│          context and validation hooks   │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  PHASE 2: BUILD                         │
│                                         │
│  For each step:                         │
│    1. Execute micro-actions             │
│    2. Run validation commands           │
│    3. On fail: apply fix hints, retry   │
│    4. On success: continue              │
│                                         │
│  Quality Gate (Stop hook):              │
│    - Run all quality checks             │
│    - STRONG/SOUND = complete            │
│    - BLOCK = fix required               │
│                                         │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  PHASE 3: BACKLOG UPDATE                │
│                                         │
│  1. Update task status to COMPLETE      │
│  2. Update feature/epic progress        │
│  3. Show next ready task                │
│                                         │
└─────────────────────────────────────────┘
         │
         ▼
    ✓ BUILD COMPLETE
```

## File Structure

```
.studio/                        # Project output directory
├── backlog.json               # Epic > Feature > Task hierarchy
├── id-map.json                # Short ID to full ID mapping
├── project.json               # Project metadata
└── tasks/
    └── [task_id]/
        ├── plan.json          # Execution-ready plan
        ├── manifest.json      # State and progress
        └── build-log.json     # Execution history

studio/                        # Plugin source (this repo)
├── memory/                    # User preferences
│   ├── global.md
│   └── [domain].md
│
├── team/                      # Domain experts
│   ├── tier1/
│   ├── tier2/
│   └── tier3/
│
├── playbooks/                 # Methodologies
│   ├── planning/
│   ├── building/
│   └── memory/
│
└── scripts/
    ├── backlog.sh             # Backlog CRUD operations
    ├── project.sh             # Project management
    └── output.sh              # Terminal formatting
```

## Build States

| State | Description |
|-------|-------------|
| `PLANNING` | Planner gathering requirements |
| `READY_TO_BUILD` | Plan complete, ready to execute |
| `BUILDING` | Builder executing steps |
| `AWAITING_QUALITY_GATE` | All steps done, running checks |
| `BLOCKED` | Quality gate failed, fixes needed |
| `COMPLETE` | All done, quality gate passed |
| `HALTED` | Step failed after max retries |
| `ABORTED` | User cancelled |

## Memory Integration

The Planner loads rules from `studio/memory/`:
- `global.md` - Always applied
- `frontend.md` - For frontend tasks
- `backend.md` - For backend tasks
- `testing.md` - For test requirements
- `security.md` - For security requirements

Rules are **embedded in the plan** so the Builder never needs to reload them.

## Team Members

The Planner uses team member question frameworks:

**Tier 1 - Core (always loaded):**
- Business Analyst - Detailed requirements
- Orchestrator - Scope & success criteria
- Tech Lead - Architecture decisions

**Tier 1 - Domain (loaded by task type):**
- Frontend Specialist
- Backend Specialist
- UI/UX Designer

**Tier 2 - Quality:**
- QA Refiner
- Security Analyst
- DevOps Engineer

**Tier 3 - Growth:**
- Content Strategist
- Legal/Compliance
- SEO/Growth

## Quality Gate

The Stop hook runs quality checks before completion:

```json
{
  "quality_gate": {
    "checks": [
      {"name": "All tests pass", "command": "npm test", "required": true},
      {"name": "No type errors", "command": "npx tsc --noEmit", "required": true},
      {"name": "No lint errors", "command": "npm run lint", "required": false}
    ]
  }
}
```

Verdicts:
- **STRONG** - All checks pass
- **SOUND** - Required pass, optional warnings
- **BLOCK** - Required check failed

## Example Sessions

### Auto-Select Next Task

```
User: /build

Build: Checking backlog...
       ✓ Found 12 tasks, 4 ready

       Scoring ready tasks:
       ├── T8 - Password reset email (score: 92)
       ├── T15 - Add Stripe SDK (score: 78)
       └── T12 - Unit tests (score: 65)

       Executing: T8 - Password reset email

Planner: Loading context from backlog...
         ✓ Task: T8 - Password reset email
         ✓ Feature: F2 - Password Reset
         ✓ Epic: E1 - User Management

         Creating plan for T8...
         ✓ 3 steps identified
         ✓ Plan saved

Builder: Executing T8...
         [Step 1/3] ✓ Create email template
         [Step 2/3] ✓ Add send function
         [Step 3/3] ✓ Integration test

         Quality Gate: STRONG ✓

Build: ✓ T8 Complete
       Updating backlog...
       ├── T8: PENDING → COMPLETE
       └── F2 Progress: 67% → 100%

       Next ready: T15 - Add Stripe SDK
       Run /build to continue
```

### Build Specific Feature

```
User: /build F3

Build: Building Feature: F3 - User Profile
       ├── T9 - Profile API endpoint
       ├── T10 - Profile UI component
       └── T11 - Profile tests

       Executing in dependency order...

       [T9] Creating plan...
            Executing...
            ✓ Complete

       [T10] Creating plan...
             Executing...
             ✓ Complete

       [T11] Creating plan...
             Executing...
             ✓ Complete

       ╔═══════════════════════════════════════╗
       ║  FEATURE COMPLETE: F3 - User Profile  ║
       ╚═══════════════════════════════════════╝

       Next: F4 - Settings (3 tasks)
```

### Plan Then Build

```
User: /build "Add dark mode toggle"

Build: New goal detected - decomposing...

Architect: Analyzing goal...
           This fits under existing structure:
           └── E1 - User Management
               └── F2 - UI Settings (creating)

           Created:
           └── T20 - Dark mode toggle

           Executing T20...

Planner: Creating plan for T20...
         ✓ 4 steps identified

Builder: Executing...
         [Step 1/4] ✓ Theme context
         [Step 2/4] ✓ CSS variables
         [Step 3/4] ✓ Toggle component
         [Step 4/4] ✓ Tests

         Quality Gate: STRONG ✓

         ╔═══════════════════════════════════════╗
         ║      BUILD COMPLETE: T20              ║
         ╚═══════════════════════════════════════╝
```

### Traditional Goal Build

```
User: /build Add user registration with email verification

Planner: Loading playbooks...
         ✓ Plan-and-Solve methodology loaded
         ✓ Memory protocol loaded

Planner: Loading team...
         ✓ Business Analyst
         ✓ Orchestrator
         ✓ Tech Lead
         ✓ Backend Specialist

Planner: Before I create a plan, I need to understand your requirements.

         1. What fields should registration capture?
         2. How should email verification work?
         3. What happens after verification?

User: Email, password, name. Send verification link. Redirect to dashboard.

Planner: Creating plan...
         ✓ 6 steps identified
         ✓ Context embedded (4 rules, 5 patterns)
         ✓ Validation hooks defined
         ✓ Plan saved: .studio/tasks/.../plan.json

         Ready for execution.

Builder: Loading plan...
         ✓ 6 steps to execute
         ✓ Context embedded

Builder: Step 1/6: Create validation schema
         → mkdir -p src/schemas
         → Write src/schemas/auth.ts
         ✓ Validating... PASS

Builder: Step 2/6: Create auth service
         → Write src/services/auth.ts
         ✗ Validating... FAIL (import error)
         → Applying fix hint: check bcrypt import
         → Retrying (1/3)...
         ✓ Validating... PASS

[...continues...]

Builder: All steps executed
         Triggering quality gate...

         ✓ npm test - PASS (12 tests)
         ✓ tsc --noEmit - PASS
         ✓ npm run lint - PASS

         ╔═══════════════════════════════════════╗
         ║         VERDICT: STRONG ✓             ║
         ╚═══════════════════════════════════════╝

         BUILD COMPLETE
```

## Backlog Status Updates

After each task completes, the build command updates the backlog:

```bash
# Update task status
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" update-status T8 COMPLETE "Build successful" builder

# Get next task
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" next-task
```

This maintains:
- Immutable changelog for each item
- Progress metrics (completion percentage)
- Feature/Epic status propagation
