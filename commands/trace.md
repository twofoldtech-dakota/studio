---
name: trace
description: Display requirements traceability matrix showing requirement-to-implementation mapping
arguments:
  - name: task_id
    description: Optional task ID (uses active task if not specified)
    required: false
triggers:
  - "/trace"
  - "/build:trace"
---

# Requirements Traceability

Display the full traceability from requirements through implementation to verification.

## Purpose

The traceability matrix proves that:
1. Every requirement has been implemented
2. Every implementation can be traced to a requirement
3. Every requirement has verification (tests)

## Command Usage

```bash
/trace              # Show traceability for active task
/trace [task_id]    # Show traceability for specific task
```

## Output Format

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  REQUIREMENTS TRACEABILITY                                                     ║
╠═══════════╦═══════════════════════════════╦═══════════════╦════════════════════╣
║ REQ ID    ║ Description                   ║ Steps         ║ Verification       ║
╠═══════════╬═══════════════════════════════╬═══════════════╬════════════════════╣
║ REQ-001   ║ User registration             ║ STEP-1,2      ║ auth.test.ts:12    ║
║ REQ-002   ║ Password validation           ║ STEP-1        ║ auth.test.ts:24    ║
║ REQ-003   ║ Email uniqueness              ║ STEP-3        ║ auth.test.ts:36    ║
║ REQ-004   ║ JWT token on success          ║ STEP-4        ║ auth.test.ts:48    ║
╚═══════════╩═══════════════════════════════╩═══════════════╩════════════════════╝

Coverage: 4/4 requirements implemented and verified (100%)
```

## Data Sources

The trace command reads from:

1. **manifest.json** - `requirements.functional[]` and `requirements.non_functional[]`
2. **plan.json** - `steps[].linked_requirements[]`
3. **Test files** - Comments linking to requirements (e.g., `// REQ-001`)

## Traceability Structure

Each requirement should have:

```json
{
  "id": "REQ-001",
  "description": "User registration with email validation",
  "priority": "must",
  "status": "implemented",
  "linked_steps": ["step_1", "step_2"],
  "verification": {
    "test_file": "tests/auth.test.ts",
    "test_line": 12,
    "verified_at": "2026-02-01T12:00:00Z"
  }
}
```

## Implementation

The trace command uses `manifest.sh trace`:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/manifest.sh" trace [task_id]
```

This:
1. Reads requirements from manifest.json
2. Cross-references with plan.json steps
3. Searches test files for requirement comments
4. Calculates coverage percentage
5. Displays formatted traceability matrix

## Coverage Calculation

```
Coverage = (requirements with verification) / (total requirements) × 100
```

A requirement is considered "verified" if:
- It has `linked_steps` that are marked complete
- AND it has a `verification.test_file` reference
- OR it has `verification.manual_check: true` for non-automatable requirements

## Gap Detection

The trace command also shows:

### Unimplemented Requirements
Requirements without linked steps:
```
⚠ REQ-005: No implementation steps found
```

### Unverified Implementations
Steps without test coverage:
```
⚠ STEP-3: No verification found
```

### Orphan Implementations
Code that doesn't trace to a requirement:
```
⚠ STEP-6: Not linked to any requirement
```

## Example Session

```
User: /trace

Planner: Reading traceability data for task_20260201_143022...

╔═══════════════════════════════════════════════════════════════════════════════╗
║  REQUIREMENTS TRACEABILITY: task_20260201_143022                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣

FUNCTIONAL REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════════

│ REQ ID    │ Description                   │ Steps         │ Verification       │
├───────────┼───────────────────────────────┼───────────────┼────────────────────┤
│ REQ-001   │ User registration             │ step_1,2      │ ✓ auth.test.ts:12  │
│ REQ-002   │ Password validation           │ step_1        │ ✓ auth.test.ts:24  │
│ REQ-003   │ Email uniqueness              │ step_3        │ ✓ auth.test.ts:36  │
│ REQ-004   │ JWT token on success          │ step_4        │ ⚠ No test found    │

NON-FUNCTIONAL REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════════

│ REQ ID    │ Description                   │ Steps         │ Verification       │
├───────────┼───────────────────────────────┼───────────────┼────────────────────┤
│ NFR-001   │ Response time < 200ms         │ step_4        │ ✓ perf.test.ts:5   │

COVERAGE SUMMARY
═══════════════════════════════════════════════════════════════════════════════

  Implemented:  5/5 requirements (100%)
  Verified:     4/5 requirements (80%)

  ⚠ Gaps found:
    - REQ-004: Missing test verification

Recommendation: Add tests for REQ-004 before completing build.
```

## Integration with Build Process

The trace command can be run:

1. **After planning** - Verify requirements are linked to steps
2. **After building** - Verify implementations are complete
3. **Before completion** - Verify all requirements are tested

Use `/build:trace` as an alias to check traceability during an active build.

## Terminal Output Commands

```bash
# Display trace header
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header trace

# Display requirement rows using table
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" table "REQ ID|Description|Steps|Verification" \
  "REQ-001|User registration|step_1,2|auth.test.ts:12" \
  "REQ-002|Password validation|step_1|auth.test.ts:24"

# Display coverage
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" progress_bar 4 5 "Coverage"
```
