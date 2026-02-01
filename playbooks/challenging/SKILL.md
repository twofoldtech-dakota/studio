# Challenging Playbook

**Purpose:** Adversarial review of plans before execution. Catch flaws when they're cheap to fix.

---

## Core Principle

The best time to find a problem is before code is written. Challenge every plan as if you're trying to break it.

---

## The Five Challenges

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

## Challenge Output Format

After running all five challenges, produce:

```
CHALLENGE RESULTS
=================

REQUIREMENTS: [PASS | GAPS FOUND]
- [List any missing coverage]

EDGE CASES: [PASS | RISKS FOUND]
- [List unhandled cases]

SIMPLICITY: [PASS | OVERCOMPLICATED]
- [List unnecessary complexity]

INTEGRATION: [PASS | CONFLICTS FOUND]
- [List conflicts with existing code]

FAILURE MODES: [PASS | UNHANDLED FAILURES]
- [List dangerous failure modes]

VERDICT: [APPROVED | REVISE PLAN]

REQUIRED CHANGES (if REVISE):
1. [Specific change needed]
2. [Specific change needed]
```

---

## When to Skip Challenges

Skip the full challenge process for:
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

## Key Insight

**Your goal is NOT to block progress. Your goal is to catch the issues that would waste hours of debugging later.**

A good challenge finds 1-2 real issues. If you're finding 10 issues, the plan wasn't ready for challenge—it needs a complete rethink.
