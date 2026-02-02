---
name: validation
description: Plan validation with confidence scoring and adversarial challenge
disable-model-invocation: false
---

# Plan Validation

Comprehensive validation of plans before execution. Combines adversarial challenge review with confidence scoring to catch flaws when they're cheap to fix.

## Overview

Plan validation evaluates readiness across two complementary approaches:
1. **Challenge Review** - Adversarial analysis to find issues
2. **Confidence Scoring** - Quantitative assessment of plan quality

## Part 1: The Five Challenges

Challenge every plan as if you're trying to break it.

### 1. REQUIREMENTS CHALLENGE
> "Does this plan actually solve what the user asked for?"

- Restate the original goal in your own words
- Check each requirement against plan steps
- Identify requirements with NO corresponding step
- Identify steps that don't trace to any requirement

**Red flag:** If you can't map every requirement to a step, the plan is incomplete.

### 2. EDGE CASE CHALLENGE
> "What inputs or conditions would break this?"

Consider:
- Empty/null/undefined inputs
- Extremely large inputs
- Concurrent access
- Network failures
- Permission denied
- Disk full
- Invalid state transitions

**Red flag:** If the plan assumes "happy path" only, it will fail in production.

### 3. SIMPLICITY CHALLENGE
> "Is this the simplest solution that works?"

Ask:
- Can any step be removed without breaking functionality?
- Are we adding abstraction that isn't needed yet?
- Are we solving problems the user didn't ask for?
- Could a junior developer understand this approach?

**Red flag:** If explaining "why" takes longer than explaining "what," it's too complex.

### 4. INTEGRATION CHALLENGE
> "How does this interact with existing code?"

Check:
- Does it conflict with existing patterns in the codebase?
- Does it introduce inconsistency?
- Will it break existing tests?
- Does it respect existing error handling patterns?

**Red flag:** If the plan ignores codebase conventions, it will create maintenance burden.

### 5. FAILURE MODE CHALLENGE
> "When this fails (not if), what happens?"

For each step, ask:
- What's the blast radius of failure?
- Can we recover, or is manual intervention needed?
- Will the user know something went wrong?
- Is there data loss risk?

**Red flag:** If any step can fail silently or cause data loss, add safeguards.

---

## Part 2: Confidence Scoring

Calculate a confidence score across four dimensions (100 points total):

### Requirements Completeness (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| All personas consulted | 10 | Core team members loaded and their questions asked |
| User confirmed requirements | 10 | `gathered_requirements.user_confirmations` is non-empty |
| Edge cases identified | 5 | `gathered_requirements.edge_cases` has 2+ items |

### Step Quality (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| All steps atomic | 10 | Each step has single `primary_tool` and clear purpose |
| All steps have validation | 10 | Every step has `success_criteria` with `validation_command` |
| Dependencies clear | 5 | `depends_on` defined and no circular dependencies |

### Context Coverage (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| Memory rules embedded | 10 | `embedded_context.memory_rules` has content |
| Patterns discovered | 10 | `embedded_context.discovered_patterns` has 3+ patterns |
| Constraints documented | 5 | `embedded_context.constraints` is non-empty |

### Risk Assessment (25 points)

| Factor | Points | Condition |
|--------|--------|-----------|
| Failure modes identified | 10 | `challenge_results.failure_modes.notes` has items |
| Retry behavior defined | 10 | Every step has `retry_behavior` with hints |
| Rollback possible | 5 | Plan has rollback strategy or git snapshot |

---

## Combined Output Format

```
╔══════════════════════════════════════════════════════════════╗
║  PLAN VALIDATION RESULTS                                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  CHALLENGE RESULTS                                           ║
║  ─────────────────                                           ║
║  REQUIREMENTS: [PASS | GAPS FOUND]                           ║
║  EDGE CASES:   [PASS | RISKS FOUND]                          ║
║  SIMPLICITY:   [PASS | OVERCOMPLICATED]                      ║
║  INTEGRATION:  [PASS | CONFLICTS FOUND]                      ║
║  FAILURE MODES:[PASS | UNHANDLED FAILURES]                   ║
║                                                              ║
║  CONFIDENCE SCORE: 87%                                       ║
║  ────────────────────                                        ║
║  Requirements:    [████████░░] 80%                           ║
║  Step Quality:    [██████████] 100%                          ║
║  Context:         [████████░░] 80%                           ║
║  Risk:            [██████░░░░] 60%                           ║
║                                                              ║
║  VERDICT: [APPROVED | REVISE PLAN]                           ║
║  Recommendation: [action if needed]                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Thresholds and Recommendations

| Score | Level | Recommendation |
|-------|-------|----------------|
| 90-100% | HIGH | Proceed with confidence |
| 70-89% | MEDIUM | Proceed with caution, consider addressing warnings |
| 50-69% | LOW | Review warnings first, improve plan before building |
| <50% | CRITICAL | Do not build - improve plan significantly |

---

## When to Skip Full Validation

Skip for:
- Single-file changes under 50 lines
- Documentation-only changes
- Formatting/style changes
- Direct user instruction with explicit approach

Still do a quick REQUIREMENTS check even for simple tasks.

---

## Revision Loop

If verdict is REVISE PLAN:
1. Apply required changes to plan
2. Re-run ONLY the failed challenges
3. Repeat until APPROVED

Maximum 2 revision loops. If still failing, surface to user for decision.

---

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

---

## Integration with Planner

The Planner should:
1. Run challenges after plan construction
2. Calculate confidence score
3. Display combined results to user
4. If score < 70% or challenges fail, ask user to confirm before proceeding
5. Store results in plan: `plan.validation`

```json
{
  "validation": {
    "challenge_results": {
      "requirements": "pass",
      "edge_cases": "pass",
      "simplicity": "pass",
      "integration": "pass",
      "failure_modes": "risks_found"
    },
    "confidence_score": {
      "total": 87,
      "breakdown": {
        "requirements": 20,
        "step_quality": 25,
        "context": 20,
        "risk": 22
      }
    },
    "warnings": [
      "Only 1 edge case identified",
      "No constraints documented"
    ],
    "verdict": "APPROVED",
    "recommendation": "PROCEED_WITH_CAUTION"
  }
}
```

---

*"Your goal is NOT to block progress. Your goal is to catch the issues that would waste hours of debugging later."*
