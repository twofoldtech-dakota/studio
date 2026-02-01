---
name: verifying
description: Reflection methodology for verification and quality assurance
triggers:
  - "verify"
  - "verify"
  - "reflect"
  - "check"
  - "validate"
  - "quality"
  - "reflexion"
---

# Verifying Skill: Reflection Methodology

This skill teaches the **Reflection** methodology for systematic verification of completed work. It is based on research from "Reflexion: Language Agents with Verbal Reinforcement Learning" (Shinn et al., 2023).

## The Core Insight

Most autonomous systems fail because they declare success prematurely. They complete tasks without verifying that the work actually meets the original requirements. The Reflection methodology addresses this by making verification mandatory and systematic.

```
Traditional Approach:        Reflection Approach:
──────────────────────       ────────────────────

Plan → Execute → "Done!"     Plan → Execute → Reflect → Verified?
       (hope it worked)                              ↓
                                               ┌────┴────┐
                                               ↓         ↓
                                              Yes       No
                                               ↓         ↓
                                            "Done!"   Fix → Reflect
                                                          ↓
                                                       (loop until verified)
```

## The Reflection Process

Reflection follows a systematic process:

```
┌─────────────────────────────────────────────────────────────┐
│                    REFLECTION PROCESS                       │
│                                                             │
│   1. GATHER      Collect all relevant information           │
│        ↓                                                    │
│   2. COMPARE     Check work against original requirements   │
│        ↓                                                    │
│   3. IDENTIFY    Find gaps between intent and reality       │
│        ↓                                                    │
│   4. CLASSIFY    Categorize issues by severity              │
│        ↓                                                    │
│   5. DECIDE      Render verdict based on findings           │
│        ↓                                                    │
│   ┌────┴────┐                                               │
│   ↓         ↓                                               │
│ PASS      FAIL                                              │
│   ↓         ↓                                               │
│ Complete  Return for fixes                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Phase 1: Gather Context

Before verifying, gather everything needed:

### What to Gather

**Original Intent**
- The stated goal
- All requirements (explicit and implicit)
- Success criteria defined in plan
- Quality standards specified

**Execution Record**
- What was planned
- What was actually done
- Any deviations or replans
- Artifacts produced

**Current State**
- Files created or modified
- Tests and their results
- Build status
- System state

### Gathering Methods

```
Gather Plan:
  → Read studio/tasks/[id]/plan.yaml

Gather Build Log:
  → Read studio/tasks/[id]/build_log.jsonl

Gather Artifacts:
  → List all files in artifacts list
  → Verify each file exists
  → Prepare for content verification

Gather Quality Data:
  → Run test suites
  → Run linters
  → Run type checkers
```

## Phase 2: Compare to Requirements

Systematically compare work to original requirements:

### Goal Achievement Check

The most fundamental question: **Did we achieve the goal?**

```yaml
goal_check:
  original_goal: "Create a REST API endpoint for user registration"

  achievement_criteria:
    - criterion: "POST endpoint exists"
      check: "Route is defined and reachable"
      result: "pass|fail"

    - criterion: "Endpoint accepts registration data"
      check: "Request body is processed correctly"
      result: "pass|fail"

    - criterion: "Users are created in database"
      check: "Successful registration persists user"
      result: "pass|fail"

  overall_achievement: "achieved|partial|not_achieved"
```

### Step Completion Check

For each step in the plan:

```yaml
step_check:
  - step_id: "step_1"
    step_name: "Create validation schema"
    executed: true|false
    success_criteria:
      - criterion: "File exists at src/schemas/auth.ts"
        method: "File existence check"
        result: "pass|fail"
      - criterion: "Schema exports registerSchema"
        method: "Export presence check"
        result: "pass|fail"
    overall: "verified|failed|skipped"
```

### Output Verification

For each expected output:

```yaml
output_check:
  - output_name: "registerSchema"
    expected_location: "src/schemas/auth.ts"
    exists: true|false
    content_correct: true|false|partial
    verification_details: "Schema exports correctly, all fields present"
```

### Quality Check Execution

Run all quality checks and record results:

```yaml
quality_checks:
  - name: "Unit tests pass"
    command: "npm test"
    exit_code: 0
    output_summary: "24 tests, 24 passing"
    result: "pass"

  - name: "No TypeScript errors"
    command: "npx tsc --noEmit"
    exit_code: 0
    output_summary: "No errors"
    result: "pass"

  - name: "Lint checks pass"
    command: "npm run lint"
    exit_code: 0
    output_summary: "No warnings or errors"
    result: "pass"
```

## Phase 3: Identify Gaps

Gaps are differences between intent and reality:

### Gap Types

**Missing Implementation**
- Feature not implemented
- File not created
- Logic not present

**Incorrect Implementation**
- Feature works wrong
- Logic has errors
- Output malformed

**Incomplete Implementation**
- Partial functionality
- Edge cases not handled
- Error handling missing

**Quality Gaps**
- Tests not written
- Documentation missing
- Code style violations

### Gap Documentation

```yaml
gaps_found:
  - id: "gap_1"
    type: "incomplete"
    location: "src/services/auth.ts"
    description: "Password hashing uses default cost factor, should use 12"
    severity: "important"
    fix_required: true

  - id: "gap_2"
    type: "missing"
    location: "src/controllers/auth.ts"
    description: "Rate limiting not implemented"
    severity: "minor"
    fix_required: false
```

## Phase 4: Classify Issues

Issues are classified by severity to determine verdict:

### Severity Levels

**Critical**
- Core functionality broken
- Security vulnerabilities
- Data integrity risks
- System stability threats

Criteria for critical:
- Cannot be worked around
- Affects all users
- Could cause data loss
- Creates security holes

**Important**
- Significant functionality gaps
- Poor error handling
- Missing validation
- Quality issues

Criteria for important:
- Noticeable to users
- Degrades experience
- Could cause confusion
- Below acceptable quality

**Minor**
- Cosmetic issues
- Style inconsistencies
- Optional improvements
- Nice-to-haves

Criteria for minor:
- Rarely noticed
- Doesn't affect function
- Subjective preference
- Enhancement rather than fix

### Classification Rules

```
IF issue prevents core functionality
   OR creates security risk
   OR could cause data loss
   THEN severity = CRITICAL

ELSE IF issue affects user experience
   OR violates requirements
   OR below quality threshold
   THEN severity = IMPORTANT

ELSE
   severity = MINOR
```

## Phase 5: Render Verdict

Based on all findings, render a verdict:

### Verdict Definitions

**STRONG**
```
All requirements met.
All steps completed.
All outputs verified.
All quality checks pass.
No issues of any severity.

→ Task completes successfully.
→ Work is production-ready.
```

**SOUND**
```
Core requirements met.
Most or all steps completed.
All critical outputs verified.
Quality checks pass.
Only minor issues present.

→ Task completes with notes.
→ Work is acceptable, improvements optional.
```

**UNSTABLE**
```
Most requirements met.
Some steps incomplete or problematic.
Some outputs missing or incorrect.
Some quality checks fail.
Important (non-critical) issues present.

→ Task returns to build.
→ Specific fixes required.
→ Re-verify after fixes.
```

**FAILED**
```
Requirements not met.
Multiple steps failed.
Critical outputs missing.
Quality checks fail significantly.
Critical issues present.

→ Task may need re-planing.
→ Fundamental problems exist.
→ Cannot proceed without major changes.
```

### Verdict Decision Matrix

```
                    │ No Issues │ Minor Only │ Important │ Critical │
────────────────────┼───────────┼────────────┼───────────┼──────────┤
All Criteria Met    │  STRONG   │   SOUND    │  UNSTABLE  │ FAILED  │
Most Criteria Met   │  SOUND    │   SOUND    │  UNSTABLE  │ FAILED  │
Some Criteria Met   │  UNSTABLE  │  UNSTABLE   │  UNSTABLE  │ FAILED  │
Few Criteria Met    │  FAILED  │  FAILED   │  FAILED  │ FAILED  │
```

### Confidence Level

Assign a confidence percentage based on:
- Thoroughness of verification
- Clarity of results
- Ambiguity in findings

```
95-100%: All checks performed, clear results, no ambiguity
80-94%:  Most checks performed, mostly clear results
60-79%:  Some checks performed, some uncertainty
Below 60%: Incomplete verification, significant uncertainty
```

## The Verify Report

Every verify produces a comprehensive report:

```
═══════════════════════════════════════════════════════════════════════════════
                              VERIFY REPORT
═══════════════════════════════════════════════════════════════════════════════

Task ID: task_20250115_143022
Plan ID: bp_20250115_143022_a7f3
Verified At: 2025-01-15T14:48:00Z

───────────────────────────────────────────────────────────────────────────────
                              VERDICT: SOUND
                            Confidence: 92%
───────────────────────────────────────────────────────────────────────────────

GOAL VERIFICATION
─────────────────
Original Goal: Create a REST API endpoint for user registration with email
               validation

Achievement: YES
Evidence:
  • POST /api/auth/register endpoint exists and responds
  • Email validation rejects invalid formats
  • Valid registrations create user records
  • Appropriate error codes returned for all cases

STEP VERIFICATION
─────────────────
[✓] Step 1: Create validation schema
    All criteria met, schema validates correctly

[✓] Step 2: Create auth service
    All criteria met, service functions correctly

[✓] Step 3: Create auth controller
    All criteria met, controller handles requests

[✓] Step 4: Create auth route
    All criteria met, route registered

[✓] Step 5: Write unit tests
    All criteria met, 18 tests passing

[✓] Step 6: Write integration tests
    All criteria met, 6 tests passing

Steps: 6/6 verified (100%)

OUTPUT VERIFICATION
───────────────────
[✓] src/schemas/auth.ts - Present, exports registerSchema
[✓] src/services/auth.ts - Present, exports registerUser
[✓] src/controllers/auth.ts - Present, exports register handler
[✓] src/routes/auth.ts - Present, POST /register defined
[✓] tests/unit/services/auth.test.ts - Present, all tests pass
[✓] tests/integration/auth.test.ts - Present, all tests pass

Outputs: 6/6 verified (100%)

QUALITY CHECKS
──────────────
[✓] npm test: 24 tests passing (0 failures)
[✓] npm run typecheck: No TypeScript errors
[✓] npm run lint: No lint errors

Quality: 3/3 checks passing (100%)

DRIFT ANALYSIS
──────────────
Scope: None detected
  Work matches scope defined in plan

Approach: Minor positive deviation
  Used more comprehensive email validation library than minimum required

Quality: Meets standards
  All specified quality checks pass

ISSUES FOUND
────────────
Critical: 0
Important: 0
Minor: 2
  • Password strength feedback could be more detailed
  • Could add request ID to error responses for debugging

VERDICT RATIONALE
─────────────────
The implementation meets all specified requirements. The goal of creating a
user registration endpoint with email validation is fully achieved. All
planned steps were completed successfully, all outputs are present and
verified, and all quality checks pass. Only minor enhancement suggestions
were identified, none of which affect functionality or quality.

The verdict is SOUND rather than STRONG only because of the minor improvement
opportunities noted. The work is production-ready.

COMPLETION APPROVED
───────────────────
This task may proceed to completion.

═══════════════════════════════════════════════════════════════════════════════
```

## Re-verifying After Fixes

When work returns after UNSTABLE verdict:

### Process

1. **Review Previous Report** - What issues were identified?
2. **Verify Fixes** - Has each issue been addressed?
3. **Check for Regressions** - Did fixes break anything?
4. **Re-run Full Verification** - Complete verification again
5. **Render New Verdict** - Based on updated findings

### Focused Verification

```
RE-VERIFYING
════════════

Previous Verdict: UNSTABLE
Issues to Verify Fixed:
  1. Password hashing cost factor (was 10, should be 12)
  2. Missing rate limiting on endpoint

Issue Verification:
  [✓] Issue 1: Fixed - Cost factor now 12
  [✓] Issue 2: Fixed - Rate limiting implemented (100 req/15min)

Regression Check:
  [✓] All previously passing tests still pass
  [✓] All previously verified outputs still correct
  [✓] No new issues introduced

Re-running Full Verification...
[Full verification results]

New Verdict: STRONG
All issues resolved, no regressions, all criteria met.
```

## Verification Techniques

### File Verification

```bash
# Check file exists
test -f "path/to/file" && echo "EXISTS" || echo "MISSING"

# Check file has content
test -s "path/to/file" && echo "HAS CONTENT" || echo "EMPTY"

# Check specific content
grep -q "pattern" file && echo "FOUND" || echo "NOT FOUND"
```

### Code Verification

```bash
# Check export exists
grep -E "export (const|function|class|interface) Name" file

# Check function signature
grep -E "function Name\(" file

# Check import
grep -E "import .* from" file
```

### Test Execution

```bash
# Run tests with output
npm test 2>&1

# Check exit code
echo "Exit code: $?"

# Run specific test file
npm test -- path/to/test.ts
```

### Type Checking

```bash
# Full type check
npx tsc --noEmit

# Check specific file
npx tsc --noEmit path/to/file.ts
```

## Common Verification Pitfalls

### Pitfall 1: Assuming Success

```
Bad:  "File was created, so it must be correct"
Good: "File exists, and content matches requirements"
```

### Pitfall 2: Skipping Quality Checks

```
Bad:  "Code looks correct, skipping tests"
Good: "Running all quality checks to verify"
```

### Pitfall 3: Ignoring Edge Cases

```
Bad:  "Happy path works"
Good: "Happy path, error cases, and edge cases all verified"
```

### Pitfall 4: Rubber-Stamping

```
Bad:  "Everything seems fine, STRONG"
Good: "Systematically verified each criterion, STRONG"
```

### Pitfall 5: Being Too Harsh

```
Bad:  "Minor style issue exists, UNSTABLE"
Good: "Minor style issue noted, doesn't affect function, SOUND"
```

## The Verification Mindset

When verifying, adopt this mindset:

1. **Evidence, not assumption** - Verify, don't trust
2. **Systematic, not random** - Check everything methodically
3. **Honest, not generous** - Report what you find
4. **Constructive, not critical** - Help fix, not just judge
5. **Gate, not gatekeeper** - Quality yes, perfectionism no

## Verification Questions Checklist

Before rendering verdict, confirm:

- [ ] Have I verified goal achievement with evidence?
- [ ] Have I checked every step in the plan?
- [ ] Have I verified every expected output?
- [ ] Have I run all quality checks?
- [ ] Have I checked for drift from original intent?
- [ ] Have I classified all issues by severity correctly?
- [ ] Is my verdict supported by the evidence?
- [ ] Is my confidence level accurate?
- [ ] If UNSTABLE/FAILED, are required actions clear?

---

*"A blade untested is a blade untrusted. The verifying is where truth is revealed." - Verifying Principle*
