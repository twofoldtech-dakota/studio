---
name: studio
description: Create execution-ready plans through MANDATORY iterative questioning and context gathering
arguments:
  - name: goal
    description: The goal to plan (required)
    required: true
triggers:
  - "/studio"
  - "/s"
questioning:
  mandatory: true
  min_rounds: 3
  requires_confirmation: true
---

# STUDIO Planning Command

The `/studio` command (alias `/s`) creates execution-ready plans through a structured workflow of context gathering, **MANDATORY iterative questioning**, and plan construction.

## IMPORTANT: Questions Are Required

The Planner MUST ask questions and wait for your answers before creating a plan. This is not optional.

**Why?**
- Assumptions lead to wrong implementations
- Edge cases get missed without discussion
- You control what gets built

**The flow:**
```
/studio "goal"
    │
    ├─ PHASE 1: Context Gathering (silent - scans codebase)
    │
    ├─ PHASE 2: Questioning Rounds (MANDATORY - waits for your answers)
    │   ├─ Round 1: Scope & Success → WAIT
    │   ├─ Round 2: Technical Constraints → WAIT  
    │   ├─ Round 3: Edge Cases (adversarial) → WAIT
    │   └─ Readiness Check: "Create plan now?" → WAIT
    │
    └─ PHASE 3: Plan Construction (only after you confirm)
           └─ Output: .studio/tasks/{id}/plan.json
```

## Phase 1: Context Gathering

### 1.1 Load Project Learnings

Load learnings from previous build cycles to inform planning:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase context-gathering
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent planner "Loading project learnings..."
```

Read learnings files:
- `studio/learnings/global.md` - Always load
- Detect relevant domains from goal and load those files
- Check `studio/learnings/integrations/` for library-specific learnings

```bash
# Detect relevant domains
"${CLAUDE_PLUGIN_ROOT}/scripts/learnings.sh" detect "$GOAL"

# Inject learnings into context
"${CLAUDE_PLUGIN_ROOT}/scripts/learnings.sh" inject global frontend backend
```

### 1.2 Analyze Codebase

Scan the project structure to understand:
- Tech stack (package.json, requirements.txt, etc.)
- Directory structure and naming conventions
- Existing patterns and component structure
- Import style (relative vs absolute, aliases)

### 1.3 Check Git Status

Understand current state:
- Current branch
- Uncommitted changes
- Recent commits for context

### 1.4 Load Backlog Context

If `.studio/backlog.json` exists:
- Load existing epics, features, and tasks
- Understand what's already planned
- Find where new work fits

### 1.5 Context7 MCP Integration (if available)

For library-specific planning, use Context7 to fetch relevant documentation:

1. Detect libraries from `package.json` or `requirements.txt`
2. Call `resolve-library-id` for each relevant library
3. Call `query-docs` for patterns related to the goal
4. Embed relevant documentation snippets in plan context

```
Example: Planning "Add form validation"
-> Detect: react-hook-form, zod in package.json
-> Query Context7 for form validation patterns
-> Embed best practices in plan
```

## Phase 2: MANDATORY Questioning Rounds

**The Planner MUST ask these questions and WAIT for your answers. It will NOT proceed without your input.**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase requirements-gathering
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent planner "Before I create a plan, I need to understand your requirements."
```

### Round 1: Scope & Success (REQUIRED)

The Planner will ask:

1. "What functionality is IN scope for this task?"
2. "What is explicitly OUT of scope?"
3. "How will you know when this is complete?"

**→ Planner WAITS for your response before continuing.**

### Round 2: Technical Constraints (REQUIRED)

The Planner will ask:

1. "Are there existing patterns in the codebase I should follow?"
2. "What dependencies or integrations are needed?"
3. "Are there any technical constraints I should be aware of?"

**→ Planner WAITS for your response before continuing.**

### Round 3: Edge Cases & Adversarial Questions (REQUIRED)

The Planner will ask challenging questions specific to your goal:

- "What if the user provides invalid input?"
- "What happens if [external dependency] is unavailable?"
- "Could this conflict with existing feature X?"
- "What's the minimum viable implementation?"

**→ Planner WAITS for your response before continuing.**

### Readiness Confirmation (REQUIRED)

After Round 3, the Planner will ask:

```
"I have gathered your requirements. Would you like to:
1. Continue with more questions to clarify further
2. Create the plan now

Which would you prefer?"
```

**→ Planner WAITS for your confirmation before creating the plan.**

### What If You Want to Skip Questions?

You can't skip the initial rounds, but you can:
- Give brief answers: "Follow existing patterns, standard deps, no special constraints"
- Choose "Create the plan now" at the readiness check

The goal is to ensure YOU have thought through the requirements, not to slow you down.

## Phase 3: Plan Construction

### 3.1 Create Task Directory

```bash
TASK_ID="task_$(date +%Y%m%d_%H%M%S)"
mkdir -p ".studio/tasks/${TASK_ID}"
```

### 3.2 Build Plan Structure

Create `plan.json` with acceptance criteria and verification types:

```json
{
  "id": "bp_YYYYMMDD_HHMMSS_XXXX",
  "task_id": "task_YYYYMMDD_HHMMSS",
  "goal": "exact goal statement",
  "created_at": "ISO 8601 timestamp",

  "context": {
    "learnings_loaded": ["global", "frontend"],
    "patterns_discovered": {...},
    "dependencies": [...]
  },

  "gathered_requirements": {
    "scope": {
      "included": [...],
      "excluded": [...]
    },
    "success_criteria": [...],
    "user_confirmations": [...]
  },

  "acceptance_criteria": [
    {
      "id": "AC-1",
      "criterion": "Form validates email format",
      "verification": {
        "type": "test_passes",
        "test_command": "npm test -- --grep 'email validation'"
      },
      "priority": "must"
    },
    {
      "id": "AC-2",
      "criterion": "Error messages display inline",
      "verification": {
        "type": "playwright",
        "url": "http://localhost:3000/register",
        "actions": [
          {"action": "fill", "selector": "#email", "value": "invalid"},
          {"action": "click", "selector": "button[type=submit]"}
        ],
        "assertions": [
          {"type": "visible", "selector": ".error-message"}
        ]
      },
      "priority": "must"
    }
  ],

  "steps": [...],

  "quality_gates": {
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit",
    "test": "npm test",
    "security": "npm audit --audit-level=high"
  }
}
```

### 3.3 Acceptance Criteria Verification Types

Each acceptance criterion must have a verification method:

| Type | Usage | Example |
|------|-------|---------|
| `command` | Run shell command, check exit code | `{"type": "command", "command": "npm test"}` |
| `file_exists` | Check file was created | `{"type": "file_exists", "path": "src/components/Form.tsx"}` |
| `file_contains` | Check file has content | `{"type": "file_contains", "path": "...", "pattern": "export.*Form"}` |
| `test_passes` | Run specific test | `{"type": "test_passes", "test_command": "npm test -- auth"}` |
| `playwright` | UI verification | `{"type": "playwright", "url": "...", "actions": [...], "assertions": [...]}` |

### 3.4 Priority Levels

- `must` - Required for completion, blocks quality gate
- `should` - Important but not blocking
- `nice-to-have` - Optional enhancement

## Output Format

### Terminal Display

```
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent planner "Plan created:"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Task: ${TASK_ID}"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Steps: [N] execution-ready steps"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Acceptance Criteria: [N] verifiable criteria"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Run /build to start execution"
```

### File Output

Write to `.studio/tasks/${TASK_ID}/plan.json`

## Example Session

```
User: /studio "Add user registration with email verification"

Planner: Loading project context...
         Found 3 learnings in frontend domain
         Detected: Next.js, Prisma, Zod

         PHASE 2: Requirements Gathering

         Before I create a plan, I need to understand your requirements.

         1. Scope & Success:
            - What fields should registration capture?
            - What happens after successful verification?

User: Email, password, name. Redirect to dashboard after verification.

Planner: Got it. A few more questions:

         2. Technical:
            - Should I follow the existing form patterns in src/components/forms/?
            - Do you want to use the existing email service or create new?

User: Yes, follow existing patterns. Use existing email service.

Planner: 3. Edge Cases (Adversarial):
            - What if someone tries to register with an existing email?
            - What's the verification link expiration?
            - What happens if verification link is clicked twice?

User: Show error for existing email. 24hr expiration. Second click shows "already verified".

Planner: 4. Quality:
            - What test coverage? Unit + integration + e2e?
            - Any rate limiting for security?

User: Unit and integration tests. Yes, rate limit to 5 attempts per IP per hour.

Planner: Creating plan...

         Plan Created:
         - Task: task_20260202_143052
         - Steps: 8 execution-ready steps
         - Acceptance Criteria: 6 verifiable criteria
           - AC-1: Registration form renders (playwright)
           - AC-2: Validation errors show inline (playwright)
           - AC-3: Email sent on submit (test_passes)
           - AC-4: Verification link works (test_passes)
           - AC-5: Rate limiting active (test_passes)
           - AC-6: Duplicate email rejected (test_passes)

         Run /build to start execution
```

## Integration with /build

After `/plan` completes, the plan is ready for `/build`:

```bash
/build              # Executes the most recent plan
/build task_id      # Executes specific task
```

The builder will:
1. Load the plan from `.studio/tasks/{id}/plan.json`
2. Execute steps in the iterative build loop
3. Verify acceptance criteria
4. Run quality gates
5. Capture learnings

## Agent Definition

This command invokes the **Planner** agent defined in `agents/planner.yaml`.
