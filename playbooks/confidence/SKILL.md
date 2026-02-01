---
name: confidence
description: Calculate and display plan confidence score before execution
disable-model-invocation: false
---

# Confidence Scoring

Calculate a confidence score for a plan before execution. This helps identify weak areas that could cause build failures.

## Overview

Confidence scoring evaluates plan quality across four dimensions:
1. **Requirements Completeness** (25 points)
2. **Step Quality** (25 points)
3. **Context Coverage** (25 points)
4. **Risk Assessment** (25 points)

Total: 100 points

## Scoring Factors

### Requirements Completeness (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| All personas consulted | 10 | Core team members loaded and their questions asked |
| User confirmed requirements | 10 | `gathered_requirements.user_confirmations` is non-empty |
| Edge cases identified | 5 | `gathered_requirements.edge_cases` has 2+ items |

**Check:**
```javascript
const reqs = plan.gathered_requirements;
let score = 0;
if (reqs.personas_consulted?.length >= 3) score += 10;
if (reqs.user_confirmations?.length >= 1) score += 10;
if (reqs.edge_cases?.length >= 2) score += 5;
```

### Step Quality (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| All steps atomic | 10 | Each step has single `primary_tool` and clear purpose |
| All steps have validation | 10 | Every step has `success_criteria` with `validation_command` |
| Dependencies clear | 5 | `depends_on` defined and no circular dependencies |

**Check:**
```javascript
const steps = plan.steps;
let score = 0;
const allAtomic = steps.every(s => s.action?.primary_tool && s.micro_actions?.length <= 5);
if (allAtomic) score += 10;
const allValidated = steps.every(s => s.success_criteria?.every(c => c.validation_command));
if (allValidated) score += 10;
const hasDeps = steps.every(s => Array.isArray(s.depends_on));
if (hasDeps && !hasCycle(steps)) score += 5;
```

### Context Coverage (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| Memory rules embedded | 10 | `embedded_context.memory_rules` has content |
| Patterns discovered | 10 | `embedded_context.discovered_patterns` has 3+ patterns |
| Constraints documented | 5 | `embedded_context.constraints` is non-empty |

**Check:**
```javascript
const ctx = plan.embedded_context;
let score = 0;
if (ctx.memory_rules && Object.keys(ctx.memory_rules).length > 0) score += 10;
if (ctx.discovered_patterns && Object.keys(ctx.discovered_patterns).length >= 3) score += 10;
if (ctx.constraints && Object.keys(ctx.constraints).length > 0) score += 5;
```

### Risk Assessment (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| Failure modes identified | 10 | `challenge_results.failure_modes.notes` has items |
| Retry behavior defined | 10 | Every step has `retry_behavior` with hints |
| Rollback possible | 5 | Plan has rollback strategy or git snapshot |

**Check:**
```javascript
let score = 0;
if (plan.challenge_results?.failure_modes?.notes?.length > 0) score += 10;
const allRetry = plan.steps.every(s => s.retry_behavior?.fix_hints?.length > 0);
if (allRetry) score += 10;
if (plan.rollback_strategy || plan.create_snapshot) score += 5;
```

## Output Format

Display confidence score using the output.sh panel command:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" panel "PLAN CONFIDENCE: ${score}%" "${details}" "${color}"
```

Where color is:
- `green` for 90%+
- `yellow` for 70-89%
- `red` for <70%

### Detailed Output

```
╔══════════════════════════════════════════════════════════════╗
║  PLAN CONFIDENCE: 87%                                        ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Requirements:    [████████░░] 80%                           ║
║    ✓ All personas consulted (3/3)                            ║
║    ✓ User confirmed requirements                             ║
║    ⚠ Only 1 edge case identified (need 2+)                   ║
║                                                              ║
║  Step Quality:    [██████████] 100%                          ║
║    ✓ All 5 steps are atomic                                  ║
║    ✓ All steps have validation commands                      ║
║    ✓ Dependencies are clear, no cycles                       ║
║                                                              ║
║  Context:         [████████░░] 80%                           ║
║    ✓ 4 Memory rules embedded                                 ║
║    ✓ 5 patterns discovered                                   ║
║    ⚠ No constraints documented                               ║
║                                                              ║
║  Risk:            [██████░░░░] 60%                           ║
║    ✓ Retry behavior defined for all steps                    ║
║    ⚠ No failure modes analyzed                               ║
║    ⚠ No rollback strategy                                    ║
║                                                              ║
║  Recommendation: PROCEED WITH CAUTION                        ║
║  Address warnings before build for best results.             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Thresholds and Recommendations

| Score | Level | Recommendation |
|-------|-------|----------------|
| 90-100% | HIGH | Proceed with confidence |
| 70-89% | MEDIUM | Proceed with caution, consider addressing warnings |
| 50-69% | LOW | Review warnings first, improve plan before building |
| <50% | CRITICAL | Do not build - improve plan significantly |

## Integration with Planner

The Planner should:
1. Calculate confidence score after plan construction
2. Display the score to the user
3. If score < 70%, ask user to confirm before proceeding
4. Store the score in the plan: `plan.confidence_score`

```json
{
  "confidence_score": {
    "total": 87,
    "breakdown": {
      "requirements": 20,
      "step_quality": 25,
      "context": 20,
      "risk": 22
    },
    "warnings": [
      "Only 1 edge case identified",
      "No constraints documented",
      "No failure modes analyzed"
    ],
    "recommendation": "PROCEED_WITH_CAUTION"
  }
}
```

## Usage in Commands

After planning is complete:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase confidence
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent planner "Calculating plan confidence..."

# Display the score
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" panel "PLAN CONFIDENCE: 87%" "Requirements: 80%\nStep Quality: 100%\nContext: 80%\nRisk: 60%" "yellow"

# Show recommendation
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status warning "Recommendation: Address warnings before build"
```

## Improving Low Scores

### Requirements < 70%
- Load more team members and ask their questions
- Get explicit user confirmation on requirements
- Identify more edge cases

### Step Quality < 70%
- Break large steps into smaller atomic actions
- Add validation commands to all steps
- Define clear dependencies

### Context < 70%
- Load and embed more Memory rules
- Analyze codebase for patterns
- Document environment constraints

### Risk < 70%
- Run the challenge phase more thoroughly
- Add fix hints to retry behavior
- Define rollback strategy
