---
name: build
description: Execute a task through STUDIO's plan-then-build workflow
arguments:
  - name: goal
    description: The goal to accomplish (required for new builds)
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

## Command Variants

### `/build <goal>`
Start a new build with the specified goal.

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

```
/build "Add user authentication"
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
    ✓ BUILD COMPLETE
```

## File Structure

```
studio/
├── projects/
│   └── [project_id]/
│       ├── project.json
│       └── tasks/
│           └── [task_id]/
│               ├── plan.json      # Execution-ready plan
│               ├── manifest.json  # State and progress
│               └── build-log.json # Execution history
│
├── memory/                # User preferences
│   ├── global.md
│   └── [domain].md
│
├── team/                  # Domain experts
│   ├── tier1/
│   ├── tier2/
│   └── tier3/
│
└── playbooks/             # Methodologies
    ├── planning/
    ├── building/
    └── memory/
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

## Example Session

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
         ✓ Plan saved: studio/projects/.../plan.json

         Ready for /build execution.

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
