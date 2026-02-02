---
name: plan
description: Decompose a goal into Epic > Feature > Task hierarchy or analyze existing codebase
arguments:
  - name: goal
    description: Optional goal to decompose (if omitted, analyzes codebase)
    required: false
triggers:
  - "/plan"
  - "/plan:analyze"
---

# STUDIO Plan Command

The `/plan` command decomposes goals into a structured hierarchy or analyzes existing codebases to map them to the **Epic > Feature > Task** structure.

## Terminal Output

**IMPORTANT**: Use the output.sh script for all formatted terminal output.

```bash
# Display headers
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header architect

# Display phase transitions
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase context-gathering
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase domain-analysis
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase decomposition
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase dependency-mapping
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase prioritization

# Display agent messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent architect "Analyzing codebase..."

# Display status messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Epic created: E1"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Scanning directories..."
```

## Command Variants

### `/plan`

When run without arguments:

1. **If no backlog exists**: Prompt user for what they want to build
2. **If backlog exists**: Analyze codebase and map to existing hierarchy

```
/plan
  │
  ├── No backlog exists?
  │   └── "What would you like to build?" (prompt user)
  │
  └── Backlog exists?
      └── Analyze codebase → map existing code to hierarchy
          └── Show what's built vs what's planned
```

### `/plan "goal"`

Decompose a specific goal into the hierarchy:

```
/plan "Add payment processing"
  │
  ▼
┌─────────────────────────────────────────┐
│  ARCHITECT: Decomposing goal...         │
│                                         │
│  Created:                               │
│  └── Epic: E3 - Payment Processing      │
│       ├── Feature: F7 - Stripe Setup    │
│       │   ├── T15 - Add Stripe SDK      │
│       │   ├── T16 - Create payment API  │
│       │   └── T17 - Add webhook handler │
│       └── Feature: F8 - Checkout Flow   │
│           ├── T18 - Cart total calc     │
│           └── T19 - Payment form UI     │
│                                         │
│  Dependencies linked to existing work   │
│  Added 5 tasks to backlog               │
│                                         │
│  Run /build to start execution          │
└─────────────────────────────────────────┘
```

### `/plan:analyze`

Force codebase analysis mode (even with a goal):

```bash
/plan:analyze
```

## Workflow Phases

### Phase 1: Context Gathering

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase context-gathering
```

**For goal decomposition:**
1. Parse the goal statement
2. Scan existing codebase for context
3. Identify integration points

**For codebase analysis:**
1. Scan directory structure
2. Detect tech stack and frameworks
3. Identify existing modules

```bash
# Check if backlog exists
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" exists

# If analyzing codebase, scan structure
ls -la src/ 2>/dev/null || ls -la app/ 2>/dev/null || ls -la lib/ 2>/dev/null
```

### Phase 2: Domain Analysis

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase domain-analysis
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent architect "Identifying business domains..."
```

Group functionality into business domains (Epics):
- User Management (auth, profiles, settings)
- Content (posts, media, comments)
- Commerce (products, cart, checkout)
- Analytics (tracking, reporting)
- Admin (management, moderation)

### Phase 3: Decomposition

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase decomposition
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent architect "Breaking down into features and tasks..."
```

For each Epic:
1. Identify user-facing features
2. For each feature, identify buildable tasks
3. Size each task (XS, S, M, L, XL)

**Task Sizing Guidelines:**

| Size | Scope | Lines | Files |
|------|-------|-------|-------|
| XS | Single function | < 50 | 1 |
| S | Small feature | 50-100 | 1-2 |
| M | Medium feature | 100-300 | 2-4 |
| L | Large feature | 300-500 | 4-8 |
| XL | Complex feature | 500+ | 8+ |

### Phase 4: Dependency Mapping

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase dependency-mapping
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent architect "Mapping dependencies..."
```

Identify:
- Task → Task dependencies (e.g., "Create API" before "Create UI")
- Feature → Feature dependencies
- Cross-epic dependencies

### Phase 5: Prioritization

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase prioritization
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent architect "Calculating priorities..."
```

Score each task:

```
SCORE = (0.35 × priority) +
        (0.25 × dependency_unlock) +
        (0.20 × business_value) +
        (0.20 × readiness)
```

## Output Format

### Backlog Creation

Create/update `.studio/backlog.json`:

```bash
# Initialize if needed
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" init "Project Name"

# Add epic
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" add-epic "User Management" "All user functionality"

# Add feature to epic
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" add-feature E1 "Authentication" "Login and session"

# Add task to feature
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" add-task F1 "Create login API" "POST /api/auth/login"
```

### Visual Summary

Display decomposition results:

```
┌─────────────────────────────────────────┐
│  DECOMPOSITION COMPLETE                 │
│                                         │
│  Created:                               │
│  └── Epic: E1 - User Management         │
│       ├── Feature: F1 - Authentication  │
│       │   └── (existing - COMPLETE)     │
│       └── Feature: F2 - Password Reset  │
│           ├── T1 - Reset API endpoint   │
│           ├── T2 - Email sender         │
│           └── T3 - Reset UI component   │
│                                         │
│  Summary:                               │
│  ├── 1 Epic                             │
│  ├── 2 Features                         │
│  └── 3 Tasks added to backlog           │
│                                         │
│  Next: T1 - Reset API endpoint          │
│  Run /build to start execution          │
└─────────────────────────────────────────┘
```

## ID System

**Full IDs** (stored in JSON):
- Epic: `EPIC-001`, `EPIC-002`
- Feature: `FEAT-001`, `FEAT-002`
- Task: `task_20260201_120000`

**Short IDs** (for commands):
- Epic: `E1`, `E2`
- Feature: `F1`, `F2`
- Task: `T1`, `T2`

Always display both formats:
```
Epic: E1 (EPIC-001) - User Management
  Feature: F1 (FEAT-001) - Authentication
    Task: T1 (task_20260201_120000) - Create login API
```

## Codebase Analysis Mode

When `/plan` runs in an existing project:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent architect "Analyzing existing codebase..."
```

### 1. Scan Codebase Structure

```bash
# Detect framework
test -f package.json && jq '.dependencies' package.json
test -f requirements.txt && cat requirements.txt
test -f Cargo.toml && cat Cargo.toml

# Map directories
find . -type d -name 'src' -o -name 'app' -o -name 'lib' | head -20
```

### 2. Map to Hierarchy

Group existing code into logical structures:

```json
{
  "analysis_type": "existing_codebase",
  "discovered": {
    "epics": [
      {
        "name": "User Management",
        "source_paths": ["src/auth/*", "src/users/*"],
        "status": "IN_PROGRESS",
        "features": [
          {
            "name": "Authentication",
            "source_paths": ["src/auth/*"],
            "status": "COMPLETE"
          }
        ]
      }
    ]
  },
  "gaps": [
    {"type": "missing_tests", "path": "src/services/payment.ts"},
    {"type": "todo_comment", "path": "src/utils/helpers.ts:42"}
  ]
}
```

### 3. Display Analysis

```
┌─────────────────────────────────────────┐
│  ANALYZING EXISTING CODEBASE...         │
│                                         │
│  Discovered:                            │
│  ├── Epic: User Management              │
│  │   ├── Feature: Authentication ✓      │
│  │   ├── Feature: Registration ✓        │
│  │   └── Feature: Password Reset (50%)  │
│  ├── Epic: Product Catalog              │
│  │   └── Feature: Product List ✓        │
│  └── Epic: Checkout (not started)       │
│                                         │
│  Gaps Found:                            │
│  ├── 3 TODO comments                    │
│  ├── 2 files missing tests              │
│  └── 1 incomplete feature               │
│                                         │
│  Backlog: 12 tasks remaining            │
│  Next: T8 - Add password reset email    │
└─────────────────────────────────────────┘
```

## File Locations

### Input (reads)
- `.studio/backlog.json` - Existing backlog (if any)
- `.studio/project.json` - Project metadata
- Source directories (`src/`, `app/`, `lib/`)

### Output (writes)
- `.studio/backlog.json` - Created/updated backlog
- `.studio/id-map.json` - Short ID to full ID mapping

## Integration with /build

After `/plan` completes:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Run /build to start execution"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Or /build T1 to build specific task"
```

The `/build` command reads from the backlog:

```bash
# Get next task
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" next-task

# Build specific item
/build T1   # Build task T1
/build F1   # Build all tasks in feature F1
/build E1   # Build all tasks in epic E1
```

## Example Sessions

### New Project

```
User: /plan "Build a todo app"

Architect: Analyzing goal...

         What features should the todo app have?
         1. Basic CRUD operations
         2. Due dates
         3. Categories/tags
         4. User accounts

User: Basic CRUD and due dates. No accounts for now.

Architect: Creating decomposition...

         ✓ Context gathered
         ✓ Domain identified: Task Management
         ✓ Decomposition complete

         Created:
         └── Epic: E1 - Task Management
              ├── Feature: F1 - Task CRUD
              │   ├── T1 - Create task model
              │   ├── T2 - Create task API
              │   └── T3 - Create task UI
              └── Feature: F2 - Due Dates
                  ├── T4 - Add due date field
                  └── T5 - Due date picker UI

         Summary: 1 Epic, 2 Features, 5 Tasks

         Next: T1 - Create task model
         Run /build to start execution
```

### Existing Project

```
User: /plan

Architect: Found existing backlog with 12 items
           Analyzing codebase for updates...

         Discovered:
         ├── Epic: E1 - User Management (80%)
         │   ├── Feature: F1 - Auth ✓
         │   └── Feature: F2 - Profile (1 task remaining)
         └── Epic: E2 - Products (40%)
             └── Feature: F3 - Catalog (3 tasks remaining)

         No new items to add.

         Backlog: 4 tasks remaining
         Next: T8 - Complete profile update

         Run /build to continue execution
```

### Adding to Existing Project

```
User: /plan "Add dark mode"

Architect: Analyzing goal in context of existing project...

         This fits under existing Epic: E1 - User Management

         Created:
         └── Feature: F5 - UI Settings
             ├── T15 - Theme context provider
             ├── T16 - Dark mode CSS variables
             └── T17 - Theme toggle component

         Dependencies:
         └── T15 depends on F1 (Auth) - user prefs storage

         Summary: Added 1 Feature, 3 Tasks

         Next: T15 - Theme context provider
         Run /build to start execution
```

## Immutability Rules

**CRITICAL**: All operations are append-only.

- Never delete items from backlog
- Use status transitions (PENDING → COMPLETE)
- Always add changelog entries
- Preserve full history for audit

```json
{
  "changelog": [
    {
      "timestamp": "2026-02-01T12:00:00Z",
      "action": "CREATED",
      "actor": "architect",
      "new_value": {"status": "PENDING"},
      "reason": "Initial decomposition"
    }
  ]
}
```

## Agent Invocation

This command invokes the **Architect** agent:

```bash
# Read the architect agent definition
cat "${CLAUDE_PLUGIN_ROOT}/agents/architect.yaml"
```

The Architect:
- Uses claude-opus-4-5-20250514 model
- Has purple phase color
- Consults tech-lead, business-analyst, orchestrator
- Creates structured decompositions
