---
name: scribe
description: Self-learning memory system for persistent user preferences and technical constraints
triggers:
  - "remember"
  - "preference"
  - "always use"
  - "never use"
  - "rule"
  - "convention"
  - "learn"
---

# The Scribe: Self-Learning Memory System

This skill teaches the methodology for **persistent preference learning** across sessions. The Scribe enables STUDIO to remember user preferences, project conventions, and technical constraints without requiring a database.

## The Core Philosophy

> "What is written shall be remembered. What is remembered shall guide."

Most AI assistants suffer from session amnesia - they learn preferences during a session only to forget them completely the next time. The Scribe addresses this through file-based long-term memory.

```
Traditional Approach:          The Scribe Approach:
──────────────────────          ──────────────────────

Session 1: Learn preference     Session 1: Learn preference
Session 2: Forget, relearn              ↓ Write to rules/
Session 3: Forget, relearn      Session 2: Read rules, apply
         ↑________|                      ↓ No relearning
         (amnesia loop)         Session N: Read rules, apply
                                         (persistent memory)
```

## The Two Operations

The Scribe performs exactly two operations:

### 1. Context Injection (Reading)

Before any agent work begins, The Scribe:

1. **Detects** relevant domains from the task goal
2. **Reads** the global rules and domain-specific rules
3. **Injects** these rules into the agent's working context
4. **Enforces** that rules are treated as mandatory preferences

### 2. Learning Loop (Writing)

After user feedback occurs, The Scribe:

1. **Detects** a learning trigger (rejection, correction, explicit teaching)
2. **Prompts** the user to confirm if this is a permanent preference
3. **Classifies** which domain the rule belongs to
4. **Writes** the rule to the appropriate file

## The Rules Directory

All preferences are stored in `studio/rules/` as human-readable Markdown:

```
studio/rules/
├── global.md      Project-wide patterns, tone, conventions
├── frontend.md    UI/UX preferences, component patterns
├── backend.md     Architecture, API, data patterns
├── testing.md     QA requirements, coverage rules
├── security.md    Security constraints, auth patterns
├── devops.md      Deployment, infrastructure preferences
└── .scribe-meta.json  Metadata and history
```

### Why Markdown?

**Human-Readable**: Users can read, edit, and understand their rules directly
**Version Controllable**: Rules can be committed to git and shared across teams
**No Dependencies**: No database, no external services, just files
**Debuggable**: When something goes wrong, users can inspect the rules

### Rule File Format

Each domain file follows a consistent structure:

```markdown
# Frontend Rules

> Last updated: 2025-01-31T14:30:22Z
> Rule count: 5

## Component Patterns
- Use functional components with hooks exclusively
- Prefer composition over inheritance for reuse

## State Management
- Use React Query for server state
- Use Zustand for client state only

## Styling
- Use Tailwind CSS; no CSS modules or inline styles
```

## Domain Detection

The Scribe automatically detects which domains are relevant based on goal keywords:

### Detection Matrix

| Domain | Signal Keywords |
|--------|-----------------|
| Frontend | react, vue, component, ui, ux, css, styling, view, jsx, tsx, tailwind |
| Backend | api, database, service, model, controller, schema, endpoint, rest, graphql |
| Testing | test, spec, coverage, mock, jest, pytest, e2e, integration |
| Security | auth, token, jwt, permission, encryption, cors, password, credential |
| DevOps | deploy, docker, ci/cd, pipeline, kubernetes, aws, terraform |

### Detection Examples

```
Goal: "Create a React component for user profile"
Detected: frontend

Goal: "Add JWT authentication to the API"
Detected: backend, security

Goal: "Build user registration with tests"
Detected: frontend, backend, testing
```

## Context Injection Protocol

When injecting rules into agent context:

### 1. Read Rules

```bash
# Always read global rules
cat studio/rules/global.md

# Read detected domain rules
cat studio/rules/frontend.md
cat studio/rules/backend.md
```

### 2. Build Injection Block

```markdown
═══════════════════════════════════════════════════════════════════════════════
                     MANDATORY USER PREFERENCES
                        (From The Scribe's Memory)
═══════════════════════════════════════════════════════════════════════════════

## Global Rules
- Use TypeScript strict mode for all files
- Prefer explicit types over inference

## Frontend Rules
- Use functional components with hooks
- Use Tailwind CSS exclusively

═══════════════════════════════════════════════════════════════════════════════
IMPORTANT: These rules are NON-NEGOTIABLE. They represent user preferences
learned from previous sessions. Always follow these rules unless the user
explicitly overrides them for this specific task.
═══════════════════════════════════════════════════════════════════════════════
```

### 3. Acknowledge to User

```
[Scribe] Loaded 4 global rules + 3 frontend rules
```

## Learning Triggers

The Scribe activates learning when it detects:

### Trigger 1: User Rejects Proposal

When the Temperer returns BRITTLE or CRACKED and the user provides feedback:

```
[Temperer] Verdict: BRITTLE - Component uses class-based pattern

[Scribe] You indicated a preference. Is this a permanent rule?
         "Use functional components instead of class components"
         [y/N]:
```

### Trigger 2: User Manually Edits Output

When a user edits a file that was just generated:

```
[Scribe] Change detected in src/components/Profile.tsx

  You changed: class ProfileComponent extends React.Component
  To:          function Profile(): JSX.Element

  Is this a new permanent rule? [y/N]:
```

### Trigger 3: Explicit Language

When user uses teaching language:

| Phrase | Interpretation |
|--------|----------------|
| "Always use X" | Add rule: "Use X for [context]" |
| "Never do Y" | Add rule: "Avoid Y; prefer [alternative]" |
| "I prefer X over Y" | Add rule: "Prefer X over Y" |
| "We use X here" | Add rule: "Use X for [purpose]" |
| "Remember this" | Prompt for rule specification |

### Trigger 4: Explicit Teaching

When user says "remember" or "add rule":

```
User: Remember that we always use Prisma for database access

[Scribe] Got it. Adding to backend rules:
         "Use Prisma for all database access"

         Category? [1] Data Layer  [2] General  [3] Other:
```

## The Learning Loop Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    📜 THE SCRIBE - LEARNING LOOP                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Scribe] Change detected. Is this a new permanent rule?        │
│                                                                 │
│  Context: You changed `useState` to `useReducer` in             │
│           UserProfile.tsx                                       │
│                                                                 │
│  [y] Yes, remember this    [n] No, one-time change              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ If 'Y'
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  [Scribe] Which domain does this rule belong to?                │
│                                                                 │
│  [1] Global (all code)     [4] Security                         │
│  [2] Frontend              [5] DevOps                           │
│  [3] Backend               [6] Testing                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  [Scribe] Please describe this rule concisely:                  │
│                                                                 │
│  > Use useReducer instead of useState for complex state         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  [Scribe] ✓ Rule added to frontend.md                           │
│                                                                 │
│  "Use useReducer instead of useState for complex state"         │
│                                                                 │
│  This preference will be applied to all future casts.           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Rule Writing Guidelines

When writing rules, follow these principles:

### Be Concise

```
Bad:  "When creating React components you should always make sure
       to use functional components with hooks instead of the older
       class-based component pattern because..."

Good: "Use functional components with hooks; avoid class components"
```

### Be Specific

```
Bad:  "Use good patterns"
Good: "Use repository pattern for data access layer"
```

### Be Actionable

```
Bad:  "Performance matters"
Good: "Use React.memo for components receiving stable props"
```

### Include Context

```
Bad:  "Use Prisma"
Good: "Use Prisma for database access; avoid raw SQL queries"
```

## Rule Precedence

When rules potentially conflict:

1. **Domain-specific beats global** for that domain's work
2. **More specific beats less specific** in same domain
3. **User override beats stored rule** for current task only
4. **Newer rules beat older rules** if directly contradictory

### Example

```markdown
# Global Rules
- Use explicit return types on functions

# Frontend Rules
- Infer return types for simple component functions
```

For a frontend component, the frontend rule applies (infer types).
For a backend service, the global rule applies (explicit types).

## Override Syntax

Users can override rules for a specific cast:

```
/cast:ignore-rules Create a quick prototype component

[Scribe] Rules suspended for this cast only
```

Or inline:

```
User: Create a component [override: can use inline styles for this one]
```

## Metadata Tracking

The `.scribe-meta.json` tracks:

- **Version**: Schema version for migrations
- **Created/Modified**: Timestamps for auditing
- **Rule Counts**: Per-domain counts for quick reference
- **History**: Audit trail of all rule changes

### History Entry

```json
{
  "timestamp": "2025-01-31T14:30:22Z",
  "domain": "frontend",
  "action": "add",
  "rule": "Use useReducer for complex state",
  "category": "State Management",
  "cast_id": "cast_20250131_143022",
  "trigger": "user_correction"
}
```

## Integration with Agents

Each STUDIO agent must:

1. **Check for Scribe rules** before beginning work
2. **Acknowledge loaded rules** in output
3. **Follow rules as mandatory** unless overridden
4. **Prompt for learning** after significant corrections

### Agent Integration Code

```markdown
## Before You Begin

1. Check if `studio/rules/` exists
2. Detect relevant domains from task
3. Read global.md + detected domain files
4. If rules found, prepend to working context
5. Acknowledge: "[Scribe] Loaded X global + Y domain rules"
```

## The Scribe Color

The Scribe uses **Magenta** for all output. Use the output.sh script:

```bash
# Display scribe messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent scribe "Loaded 5 global rules + 3 frontend rules"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent scribe "Change detected. Is this a new permanent rule?"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent scribe "Rule added to frontend.md"
```

## Shell Utilities

The `scripts/scribe.sh` provides command-line access. Use the plugin root path and set `STUDIO_DIR` to point to the local rules directory:

```bash
# Initialize rules directory
STUDIO_DIR=studio "${CLAUDE_PLUGIN_ROOT}/scripts/scribe.sh" init

# Add a rule
STUDIO_DIR=studio "${CLAUDE_PLUGIN_ROOT}/scripts/scribe.sh" add frontend "Use Tailwind" "Styling"

# List all rules
STUDIO_DIR=studio "${CLAUDE_PLUGIN_ROOT}/scripts/scribe.sh" list

# Generate injection block
STUDIO_DIR=studio "${CLAUDE_PLUGIN_ROOT}/scripts/scribe.sh" inject frontend backend

# Detect domains from goal
STUDIO_DIR=studio "${CLAUDE_PLUGIN_ROOT}/scripts/scribe.sh" detect "Create a React login form"

# View history
STUDIO_DIR=studio "${CLAUDE_PLUGIN_ROOT}/scripts/scribe.sh" history 10
```

## Common Patterns

### Pattern 1: Technology Preferences

```markdown
## Technology Stack
- Use TypeScript for all code
- Use Prisma for database access
- Use React Query for server state
- Use Tailwind CSS for styling
```

### Pattern 2: Code Style

```markdown
## Code Style
- Use explicit return types on exported functions
- Prefer named exports over default exports
- Use descriptive variable names; avoid abbreviations
```

### Pattern 3: Architecture Rules

```markdown
## Architecture
- Use repository pattern for data access
- Keep controllers thin; logic in services
- One file per component/class
```

### Pattern 4: Quality Requirements

```markdown
## Quality
- All exported functions must have JSDoc comments
- Test coverage minimum 80% for new code
- No console.log in production code
```

## Verification Questions

Before adding a rule, consider:

- [ ] Is this preference consistent across the project?
- [ ] Would this rule help future sessions?
- [ ] Is the rule specific enough to be actionable?
- [ ] Does this conflict with existing rules?
- [ ] Is this a project convention or personal preference?

If all answers are "yes" or "project convention," the rule should be recorded.

---

*"The Scribe remembers so you don't have to repeat." - The Scribe Principle*
