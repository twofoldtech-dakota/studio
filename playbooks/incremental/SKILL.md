---
name: incremental
description: Update only affected steps when requirements change
disable-model-invocation: false
---

# Incremental Planning

Update only affected steps when requirements change, preserving unchanged work.

## Overview

When requirements change mid-build or a plan needs revision, don't regenerate the entire plan. Instead:

1. Identify which requirements changed
2. Find steps linked to those requirements
3. Regenerate only affected steps
4. Preserve unchanged steps and their validation results

## When to Use

- User refines requirements during review
- Partial build completed, scope changed
- Single requirement clarified
- Edge case discovered that affects subset of steps

## Process

### Step 1: Identify Changed Requirements

Compare old vs new requirements:

```json
{
  "changes": [
    {
      "id": "REQ-003",
      "type": "modified",
      "old": "Email validation",
      "new": "Email validation with domain whitelist"
    },
    {
      "id": "REQ-005",
      "type": "added",
      "new": "Support for SSO login"
    }
  ]
}
```

### Step 2: Find Linked Steps

Query plan to find steps linked to changed requirements:

```bash
# Find steps linked to REQ-003
jq '.steps[] | select(.linked_requirements[] == "REQ-003") | .id' plan.json
```

Example output:
```
"step_1"   # Create validation schema
"step_5"   # Write tests
```

### Step 3: Classify Impact

For each affected step, classify the impact:

| Impact | Definition | Action |
|--------|------------|--------|
| **REGENERATE** | Core logic changed | Full step regeneration |
| **AUGMENT** | Additive change | Add micro-actions |
| **VALIDATION_ONLY** | Only tests affected | Update success_criteria |
| **NONE** | No actual impact | Keep as-is |

### Step 4: Preserve Unchanged Steps

Keep existing data for unchanged steps:
- `micro_actions` - Already validated
- `success_criteria` - Already passing
- `completed_at` - Preserve timing
- `attempts` - Preserve history

### Step 5: Generate Delta

Output the incremental update:

```json
{
  "incremental_update": {
    "generated_at": "ISO 8601",
    "trigger": "requirement_change",
    "changes": [
      {
        "requirement_id": "REQ-003",
        "change_type": "modified"
      }
    ],
    "affected_steps": ["step_1", "step_5"],
    "preserved_steps": ["step_2", "step_3", "step_4"],
    "regenerated": [
      {
        "id": "step_1",
        "name": "Create validation schema",
        "impact": "REGENERATE",
        "new_micro_actions": [...],
        "new_success_criteria": [...]
      }
    ]
  }
}
```

## Implementation Example

```javascript
function incrementalUpdate(oldPlan, changedReqs) {
  // Find affected steps
  const affectedSteps = changedReqs.flatMap(req =>
    oldPlan.steps.filter(s =>
      s.linked_requirements &&
      s.linked_requirements.includes(req.id)
    )
  );

  const affectedIds = new Set(affectedSteps.map(s => s.id));

  // Preserve unchanged steps
  const unchangedSteps = oldPlan.steps.filter(s =>
    !affectedIds.has(s.id)
  );

  // Regenerate only affected steps
  const regeneratedSteps = regenerateSteps(affectedSteps, changedReqs, oldPlan.embedded_context);

  // Merge and sort
  const newSteps = [...unchangedSteps, ...regeneratedSteps]
    .sort((a, b) => {
      const numA = parseInt(a.id.replace('step_', ''));
      const numB = parseInt(b.id.replace('step_', ''));
      return numA - numB;
    });

  return {
    ...oldPlan,
    steps: newSteps,
    incremental_update: {
      generated_at: new Date().toISOString(),
      affected_steps: Array.from(affectedIds),
      preserved_steps: unchangedSteps.map(s => s.id)
    }
  };
}
```

## Output Format

Display incremental update summary:

```
╔══════════════════════════════════════════════════════════════╗
║  INCREMENTAL PLAN UPDATE                                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Changed Requirements:                                       ║
║    • REQ-003: Modified (Email validation → with whitelist)   ║
║                                                              ║
║  Affected Steps:                                             ║
║    • step_1: Create validation schema ← REGENERATE           ║
║    • step_5: Write tests ← REGENERATE                        ║
║                                                              ║
║  Preserved Steps:                                            ║
║    • step_2: Create auth service ← UNCHANGED                 ║
║    • step_3: Create controller ← UNCHANGED                   ║
║    • step_4: Create routes ← UNCHANGED                       ║
║                                                              ║
║  Summary: Regenerating 2/5 steps (60% preserved)             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Dependency Handling

When regenerating a step, check if downstream steps need updates:

```
step_1 (REGENERATE) produces: validationSchema
    ↓
step_2 (CHECK) depends_on: step_1
    → If step_1 output interface changed: REGENERATE step_2
    → If step_1 output interface unchanged: PRESERVE step_2
```

## Integration with Build

When resuming a build after incremental update:

1. Skip steps marked as already completed (preserved)
2. Start from first regenerated step
3. Re-run validation on preserved steps that depend on regenerated steps

```bash
# Resume from incremental update
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Incremental update applied"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Resuming from step_1 (2/5 to regenerate)"
```

## Best Practices

1. **Always link requirements** - Steps must have `linked_requirements` for traceability
2. **Minimize blast radius** - Well-structured plans have localized changes
3. **Preserve completed work** - Never regenerate a step that passed validation
4. **Validate dependencies** - Check downstream steps when regenerating
5. **Log updates** - Record incremental changes for audit trail
