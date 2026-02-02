---
name: status
description: Show project dashboard with progress tracking
arguments:
  - name: id
    description: Optional Epic, Feature, or Task ID for detailed view
    required: false
triggers:
  - "/status"
---

# STUDIO Status Command

The `/status` command displays a project dashboard showing progress across the Epic > Feature > Task hierarchy.

## Terminal Output

**IMPORTANT**: Use the output.sh script for all formatted terminal output.

```bash
# Display headers
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header status

# Display status messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Task complete"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Loading backlog..."
```

## Command Variants

### `/status`

Show full project dashboard:

```
╔══════════════════════════════════════════════════════════════╗
║  PROJECT: My App                                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Progress: ████████████░░░░░░░░ 62%                         ║
║                                                              ║
║  Epics:                                                      ║
║  ├── E1 User Management    [████████░░] 80%                 ║
║  ├── E2 Product Catalog    [██████████] 100% ✓              ║
║  └── E3 Payments           [██░░░░░░░░] 20%                 ║
║                                                              ║
║  Active: T15 - Add Stripe SDK                               ║
║  Next:   T16 - Create payment API                           ║
║                                                              ║
║  Backlog: 8 tasks remaining                                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

### `/status E1`

Show detailed Epic view:

```
╔══════════════════════════════════════════════════════════════╗
║  EPIC: E1 - User Management                                  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Features:                                                   ║
║  ├── F1 Authentication [████████████] 100% ✓                ║
║  │   ├── T1 Login API ✓                                     ║
║  │   ├── T2 JWT tokens ✓                                    ║
║  │   └── T3 Session mgmt ✓                                  ║
║  │                                                           ║
║  ├── F2 Registration [████████░░░░] 67%                     ║
║  │   ├── T4 Signup form ✓                                   ║
║  │   ├── T5 Email verify ✓                                  ║
║  │   └── T6 Welcome email ○ (next)                          ║
║  │                                                           ║
║  └── F3 Password Reset [░░░░░░░░░░░░] 0%                    ║
║      ├── T7 Reset request ○                                  ║
║      └── T8 Reset flow ○ (blocked by T7)                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

### `/status F1`

Show detailed Feature view:

```
╔══════════════════════════════════════════════════════════════╗
║  FEATURE: F1 - Authentication                                ║
║  Epic: E1 - User Management                                  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Progress: [████████████] 100% ✓                            ║
║                                                              ║
║  Tasks:                                                      ║
║  ├── T1 Create login API ✓                                  ║
║  │   └── Completed 2026-01-28 (2h 15m)                      ║
║  ├── T2 Implement JWT tokens ✓                              ║
║  │   └── Completed 2026-01-29 (1h 45m)                      ║
║  └── T3 Session management ✓                                ║
║      └── Completed 2026-01-30 (3h 10m)                      ║
║                                                              ║
║  Acceptance Criteria:                                        ║
║  ✓ Users can log in with email/password                     ║
║  ✓ JWT tokens issued on successful login                    ║
║  ✓ Sessions persist across page refreshes                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

### `/status T1`

Show detailed Task view:

```
╔══════════════════════════════════════════════════════════════╗
║  TASK: T1 - Create login API                                 ║
║  Feature: F1 - Authentication                                ║
║  Epic: E1 - User Management                                  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Status: COMPLETE ✓                                         ║
║  Priority: 2 (High)                                         ║
║  Effort: S (Small) - High confidence                        ║
║                                                              ║
║  Description:                                                ║
║  Create POST /api/auth/login endpoint that validates        ║
║  credentials and returns JWT token.                         ║
║                                                              ║
║  Dependencies: None                                          ║
║  Blocks: T2, T3                                             ║
║                                                              ║
║  Timeline:                                                   ║
║  ├── Created:   2026-01-27 10:00                            ║
║  ├── Started:   2026-01-28 09:15                            ║
║  └── Completed: 2026-01-28 11:30                            ║
║                                                              ║
║  Plan: bp_20260128_091500_a7f3                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Implementation

### Prerequisites Check

```bash
# Check if backlog exists
if ! "${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" exists | grep -q "true"; then
    "${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status warning "No backlog found"
    "${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Run /plan to create one"
    exit 0
fi
```

### Load Backlog Data

```bash
# Get status
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" status

# Get specific item
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" get E1

# Get ready tasks
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" ready-tasks

# Get next task
"${CLAUDE_PLUGIN_ROOT}/scripts/backlog.sh" next-task
```

### Progress Calculation

Progress is calculated hierarchically:

```
Task Progress = COMPLETE ? 100% : 0%

Feature Progress = (completed_tasks / total_tasks) × 100%

Epic Progress = (completed_tasks_in_epic / total_tasks_in_epic) × 100%

Project Progress = (completed_tasks / total_tasks) × 100%
```

### Status Icons

| Status | Icon | Color |
|--------|------|-------|
| COMPLETE | ✓ | Green |
| IN_PROGRESS | ⟳ | Yellow |
| PENDING | ○ | Dim |
| BLOCKED | ⊘ | Red |
| CANCELLED | ✗ | Red |

### Progress Bar

Generate ASCII progress bars:

```bash
# 10-character bar at 75%
# [███████░░░] 75%

generate_bar() {
    local pct=$1
    local width=${2:-10}
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar=""

    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    echo "[$bar] ${pct}%"
}
```

## Output Sections

### 1. Project Header

```
╔══════════════════════════════════════════════════════════════╗
║  PROJECT: My App                                             ║
╠══════════════════════════════════════════════════════════════╣
```

### 2. Overall Progress

```
║  Progress: ████████████░░░░░░░░ 62%                         ║
```

### 3. Epic List

Show all epics with their progress:

```
║  Epics:                                                      ║
║  ├── E1 User Management    [████████░░] 80%                 ║
║  ├── E2 Product Catalog    [██████████] 100% ✓              ║
║  └── E3 Payments           [██░░░░░░░░] 20%                 ║
```

### 4. Active/Next Tasks

```
║  Active: T15 - Add Stripe SDK                               ║
║  Next:   T16 - Create payment API                           ║
```

### 5. Summary Stats

```
║  Backlog: 8 tasks remaining                                  ║
```

## Metrics Tracked

The status command displays metrics from `backlog.json`:

```json
{
  "metrics": {
    "total_epics": 3,
    "total_features": 8,
    "total_tasks": 24,
    "completed_tasks": 15,
    "completion_percentage": 62
  }
}
```

## Drift Tracking (Future)

Status will also show:
- Estimated vs actual effort
- Planned vs actual completion dates
- Accuracy scores

```
║  Drift Analysis:                                             ║
║  ├── Effort accuracy: 78%                                    ║
║  ├── Tasks on track: 85%                                     ║
║  └── Avg completion: 1.2x estimated                          ║
```

## Example Session

```
User: /status

╔══════════════════════════════════════════════════════════════╗
║  PROJECT: E-Commerce Platform                                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Progress: ████████████░░░░░░░░ 62%                         ║
║                                                              ║
║  Epics:                                                      ║
║  ├── E1 User Management    [████████░░] 80%                 ║
║  ├── E2 Product Catalog    [██████████] 100% ✓              ║
║  └── E3 Checkout           [██░░░░░░░░] 20%                 ║
║                                                              ║
║  Active: T12 - Cart total calculation                        ║
║  Next:   T13 - Checkout form UI                              ║
║                                                              ║
║  Backlog: 8 tasks remaining                                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

User: /status E1

╔══════════════════════════════════════════════════════════════╗
║  EPIC: E1 (EPIC-001) - User Management                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Status: IN_PROGRESS                                         ║
║  Priority: 1 (Critical)                                      ║
║  Business Value: High                                        ║
║                                                              ║
║  Features:                                                   ║
║  ├── F1 Authentication [████████████] 100% ✓                ║
║  │   ├── T1 Login API ✓                                     ║
║  │   ├── T2 JWT tokens ✓                                    ║
║  │   └── T3 Session mgmt ✓                                  ║
║  │                                                           ║
║  ├── F2 Registration [████████░░░░] 67%                     ║
║  │   ├── T4 Signup form ✓                                   ║
║  │   ├── T5 Email verify ✓                                  ║
║  │   └── T6 Welcome email ○ (next)                          ║
║  │                                                           ║
║  └── F3 Password Reset [░░░░░░░░░░░░] 0%                    ║
║      ├── T7 Reset request ○                                  ║
║      └── T8 Reset flow ○ (blocked by T7)                    ║
║                                                              ║
║  Summary: 5/8 tasks complete                                 ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Integration with Other Commands

```bash
# After /status, natural next steps:
/build          # Execute next ready task
/build T6       # Build specific task
/plan "new"     # Add more work to backlog
```

## No Backlog State

If no backlog exists:

```
╔══════════════════════════════════════════════════════════════╗
║  NO PROJECT BACKLOG                                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  No backlog found in this directory.                         ║
║                                                              ║
║  To get started:                                             ║
║  ├── /plan "goal"  - Decompose a goal                       ║
║  └── /plan         - Analyze existing codebase              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```
