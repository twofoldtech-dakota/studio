# STUDIO Improvement Recommendations

Prioritized recommendations for improving developer experience, quality, performance, and polish.

---

## Priority 1: Quick Wins (Low Effort, High Impact)

### 1.1 Progress Visualization

**Current:** No real-time progress feedback during execution.

**Recommendation:** Add progress bar and phase indicators.

```
╔══════════════════════════════════════════════════════════════╗
║  CASTING: user-registration-api                              ║
╠══════════════════════════════════════════════════════════════╣
║  Progress: [████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 30%    ║
║  Phase:    CAST (step 3/10)                                  ║
║  Current:  Creating auth service                             ║
║  ETA:      ~2 minutes                                        ║
╚══════════════════════════════════════════════════════════════╝
```

**Implementation:** Update `output.sh` with progress bar function, update caster to emit progress events.

---

### 1.2 Dry-Run Mode

**Current:** No way to preview what will happen before execution.

**Recommendation:** Add `/cast:preview` command.

```bash
/cast:preview Create user registration API

# Output:
PREVIEW MODE - No changes will be made

Would gather requirements for:
  - Authentication method
  - User data fields
  - Validation rules

Would create files:
  - src/schemas/auth.ts
  - src/services/auth.ts
  - src/controllers/auth.ts
  - src/routes/auth.ts
  - src/__tests__/auth.test.ts

Would run quality checks:
  - npm test
  - npx tsc --noEmit
  - npm run lint

Estimated steps: 5-8
```

**Implementation:** Add preview flag to architect that outputs plan without executing.

---

### 1.3 Better Error Messages

**Current:** Errors show raw output without context.

**Recommendation:** Contextual, actionable error messages.

```
╔══════════════════════════════════════════════════════════════╗
║  ❌ STEP FAILED: Create auth service                         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Error: Cannot find module 'bcrypt'                          ║
║                                                              ║
║  Why this happened:                                          ║
║  The step tried to import 'bcrypt' but it's not installed.   ║
║                                                              ║
║  How to fix:                                                 ║
║  1. Run: npm install bcrypt @types/bcrypt                    ║
║  2. Then retry: /cast resume                                 ║
║                                                              ║
║  Or let me fix it:                                           ║
║  [y] Auto-install and retry                                  ║
║  [n] Abort cast                                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

**Implementation:** Create error classifier that maps common errors to solutions.

---

### 1.4 Session Persistence

**Current:** Cast state is saved, but resuming requires knowing cast ID.

**Recommendation:** Auto-resume last active cast.

```bash
# On session start, if there's an incomplete cast:
╔══════════════════════════════════════════════════════════════╗
║  UNFINISHED CAST DETECTED                                    ║
╠══════════════════════════════════════════════════════════════╣
║  ID: cast_20260201_143022                                    ║
║  Goal: Create user registration API                          ║
║  Status: BLOCKED at step 4/6                                 ║
║  Last activity: 2 hours ago                                  ║
║                                                              ║
║  [r] Resume    [a] Abort    [n] New cast                     ║
╚══════════════════════════════════════════════════════════════╝
```

**Implementation:** SessionStart hook checks for incomplete casts.

---

## Priority 2: Quality Improvements (Medium Effort, High Impact)

### 2.1 Confidence Scoring

**Current:** Blueprint quality is not assessed before execution.

**Recommendation:** Rate blueprint quality with confidence score.

```
╔══════════════════════════════════════════════════════════════╗
║  BLUEPRINT CONFIDENCE: 87%                                   ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ✓ Requirements: 6 gathered, all confirmed                   ║
║  ✓ Steps: 5 atomic, all have validation commands             ║
║  ✓ Dependencies: Clear chain, no cycles                      ║
║  ⚠ Coverage: 3 edge cases not addressed                      ║
║  ✓ Scribe: 4 rules applied                                   ║
║                                                              ║
║  Recommendation: Proceed with confidence                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

**Scoring factors:**
- Requirements completeness (all personas consulted?)
- Step atomicity (single responsibility?)
- Validation coverage (every step has checks?)
- Dependency clarity (no circular deps?)
- Scribe alignment (rules applied?)
- Risk coverage (failure modes addressed?)

---

### 2.2 Auto-Generated Tests

**Current:** Tests must be manually specified in blueprint.

**Recommendation:** Generate test skeletons from requirements.

```typescript
// Auto-generated from REQ-001: User registration with email validation
describe('User Registration', () => {
  it('should register user with valid email and password', async () => {
    // REQ-001: Happy path
    // TODO: Implement
  });

  it('should reject invalid email format', async () => {
    // REQ-001: Edge case - invalid email
    // TODO: Implement
  });

  it('should reject weak passwords', async () => {
    // REQ-002: Password strength requirement
    // TODO: Implement
  });
});
```

**Implementation:** Add test generation step to blueprint that creates test skeletons linked to requirements.

---

### 2.3 Self-Review Hook

**Current:** Quality gate runs standard checks (tests, types, lint).

**Recommendation:** Add LLM-powered code review before completion.

```
╔══════════════════════════════════════════════════════════════╗
║  SELF-REVIEW                                                 ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Reviewing against:                                          ║
║  - Original requirements                                     ║
║  - Blueprint specifications                                  ║
║  - Scribe rules                                              ║
║  - Security best practices                                   ║
║                                                              ║
║  Findings:                                                   ║
║  ✓ All requirements implemented                              ║
║  ✓ Code matches blueprint                                    ║
║  ⚠ Consider: Add rate limiting to registration endpoint      ║
║  ⚠ Consider: Add input sanitization for name field           ║
║                                                              ║
║  Verdict: SOUND (proceed with notes)                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

**Implementation:** Add agent-type hook at Stop that reviews generated code against requirements.

---

### 2.4 Requirements Traceability Matrix

**Current:** Requirements exist but aren't linked to implementation.

**Recommendation:** Full traceability from requirement → task → artifact → test.

```
╔══════════════════════════════════════════════════════════════════════════╗
║  REQUIREMENTS TRACEABILITY                                               ║
╠═══════════╦═══════════════════════════╦═══════════════╦══════════════════╣
║ REQ ID    ║ Description               ║ Task          ║ Verification     ║
╠═══════════╬═══════════════════════════╬═══════════════╬══════════════════╣
║ REQ-001   ║ User registration         ║ TASK-001,002  ║ auth.test.ts:12  ║
║ REQ-002   ║ Password validation       ║ TASK-001      ║ auth.test.ts:24  ║
║ REQ-003   ║ Email uniqueness          ║ TASK-003      ║ auth.test.ts:36  ║
║ REQ-004   ║ JWT token on success      ║ TASK-004      ║ auth.test.ts:48  ║
╚═══════════╩═══════════════════════════╩═══════════════╩══════════════════╝

Coverage: 4/4 requirements implemented and verified (100%)
```

**Implementation:** Already in manifest schema - add `/cast trace` command to display.

---

## Priority 3: Performance Optimizations (Medium Effort, Medium Impact)

### 3.1 Parallel Step Execution

**Current:** Steps execute sequentially even when independent.

**Recommendation:** Execute independent steps in parallel.

```
Blueprint Analysis:
  step_1 → step_2 → step_3
              ↘ step_4 ↗
                  ↓
              step_5

Parallel Execution Plan:
  Batch 1: step_1
  Batch 2: step_2, step_4 (parallel - no dependencies)
  Batch 3: step_3, step_5 (parallel after batch 2)

Time savings: ~40% for this blueprint
```

**Implementation:**
1. Analyze dependency graph
2. Identify parallelizable batches
3. Execute batches using Task tool with multiple agents

---

### 3.2 Context Caching

**Current:** Skills and personas are read from disk each time.

**Recommendation:** Cache frequently-used context in session.

```yaml
cache:
  skills:
    blueprinting: <cached content>
    scribe: <cached content>
  personas:
    business-analyst: <cached content>
    tech-lead: <cached content>
  patterns:
    project_import_style: "@/ absolute imports"
    project_state_mgmt: "zustand"
```

**Implementation:** SessionStart hook loads common skills/personas into memory.

---

### 3.3 Incremental Blueprints

**Current:** Entire blueprint regenerated for any change.

**Recommendation:** Update only affected steps when requirements change.

```
Requirement changed: REQ-003 (email validation)

Affected steps:
  - step_1: Create validation schema    ← REGENERATE
  - step_2: Create auth service         ← UNCHANGED
  - step_3: Create controller           ← UNCHANGED
  - step_5: Write tests                 ← REGENERATE (tests for REQ-003)

Regenerating 2/5 steps...
```

**Implementation:** Track requirement → step mapping, only regenerate linked steps.

---

## Priority 4: Polish & DX (Lower Effort, Quality of Life)

### 4.1 Rich Terminal UI

**Current:** Basic text output with ANSI colors.

**Recommendation:** Full TUI with boxes, tables, spinners.

```
┌─ STUDIO ──────────────────────────────────────────────────────┐
│                                                              │
│  ⣾ Gathering requirements...                                 │
│                                                              │
│  ┌─ Personas Active ─────────────────────────────────────┐   │
│  │ ◉ Business Analyst   ◉ Tech Lead   ○ Security        │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ Requirements ────────────────────────────────────────┐   │
│  │ REQ-001 ✓  User registration with email              │   │
│  │ REQ-002 ✓  Password strength validation              │   │
│  │ REQ-003 ◐  Email uniqueness check (clarifying...)    │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Implementation:** Enhance output.sh with box-drawing, spinners, tables.

---

### 4.2 Interactive Step Confirmation

**Current:** Full auto-execution or manual commands.

**Recommendation:** Step-by-step confirmation mode.

```bash
/cast:interactive Create user registration API

# After each step:
╔══════════════════════════════════════════════════════════════╗
║  STEP 2/5: Create auth service                               ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Will create: src/services/auth.ts                           ║
║                                                              ║
║  Content preview:                                            ║
║  ┌────────────────────────────────────────────────────────┐  ║
║  │ import bcrypt from 'bcrypt';                           │  ║
║  │ import { db } from '@/lib/db';                         │  ║
║  │                                                        │  ║
║  │ export async function hashPassword(password: string)   │  ║
║  │ ...                                                    │  ║
║  └────────────────────────────────────────────────────────┘  ║
║                                                              ║
║  [y] Execute  [e] Edit  [s] Skip  [a] Abort                  ║
╚══════════════════════════════════════════════════════════════╝
```

---

### 4.3 Blueprint Templates

**Current:** Every blueprint starts from scratch.

**Recommendation:** Pre-built templates for common patterns.

```bash
/cast:template api-endpoint Create user profile endpoint

# Uses template: api-endpoint
# Pre-filled structure:
# - Schema step
# - Service step
# - Controller step
# - Route step
# - Test step

# Only gathers domain-specific requirements
```

**Templates library:**
- `api-endpoint` - REST endpoint with CRUD
- `react-component` - Component with tests and stories
- `database-migration` - Schema change with rollback
- `auth-flow` - Authentication feature
- `integration` - Third-party API integration

---

### 4.4 Analytics Dashboard

**Current:** No visibility into historical performance.

**Recommendation:** Track and display cast analytics.

```
╔══════════════════════════════════════════════════════════════╗
║  STUDIO ANALYTICS (Last 30 days)                              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Casts:     47 total   42 complete   3 failed   2 aborted   ║
║  Success:   89%                                              ║
║                                                              ║
║  Avg Duration:    12 minutes                                 ║
║  Avg Steps:       6.2                                        ║
║  Avg Retries:     0.8 per cast                               ║
║                                                              ║
║  Quality Verdicts:                                           ║
║  ████████████████████░░░░░░░░  STRONG: 28 (67%)              ║
║  ██████░░░░░░░░░░░░░░░░░░░░░░  SOUND:  11 (26%)              ║
║  ██░░░░░░░░░░░░░░░░░░░░░░░░░░  BRITTLE: 3 (7%)               ║
║                                                              ║
║  Most Common Failures:                                       ║
║  1. Type errors (8)                                          ║
║  2. Missing dependencies (5)                                 ║
║  3. Test failures (3)                                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Priority 5: Advanced Features (Higher Effort, Differentiating)

### 5.1 Multi-Cast Orchestration

**Current:** Single cast at a time.

**Recommendation:** Orchestrate related casts as a project.

```bash
/project:init E-commerce Platform

/project:cast User authentication
/project:cast Product catalog
/project:cast Shopping cart
/project:cast Checkout flow

# Shows dependency graph between casts
# Manages shared context
# Tracks overall project progress
```

---

### 5.2 Learning from Corrections

**Current:** Scribe records explicit rules only.

**Recommendation:** Learn from user corrections automatically.

```
Detected: User modified generated code

Original:
  const user = await db.user.create({ data: userData });

User changed to:
  const user = await db.user.create({
    data: userData,
    select: { id: true, email: true, name: true }
  });

Inferred rule: "Always use select to limit returned fields"

[y] Save this rule to backend.md
[n] Ignore (one-time change)
```

---

### 5.3 Rollback System

**Current:** No easy way to undo a cast.

**Recommendation:** Git-based rollback with snapshot.

```bash
/cast rollback

╔══════════════════════════════════════════════════════════════╗
║  ROLLBACK OPTIONS                                            ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  1. cast_20260201_150000 - User registration API             ║
║     Files changed: 5 created, 2 modified                     ║
║     [Rollback] [View diff]                                   ║
║                                                              ║
║  2. cast_20260201_140000 - Database schema update            ║
║     Files changed: 1 modified                                ║
║     [Rollback] [View diff]                                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

**Implementation:** Create git commit before each cast, tag with cast ID.

---

## Implementation Roadmap

### Phase 1: Foundation (This Sprint)
- [x] Cast Manifest schema
- [x] Manifest management script
- [ ] Update architect/caster to use manifest
- [ ] Progress visualization

### Phase 2: Quality (Next Sprint)
- [ ] Confidence scoring
- [ ] Self-review hook
- [ ] Better error messages
- [ ] Session persistence

### Phase 3: DX Polish (Following Sprint)
- [ ] Dry-run mode
- [ ] Interactive confirmation mode
- [ ] Rich terminal UI
- [ ] Blueprint templates

### Phase 4: Performance (Optimization Sprint)
- [ ] Parallel execution
- [ ] Context caching
- [ ] Incremental blueprints

### Phase 5: Advanced (Future)
- [ ] Multi-cast orchestration
- [ ] Learning from corrections
- [ ] Rollback system
- [ ] Analytics dashboard

---

## Summary

| Category | Top Recommendation | Impact | Effort |
|----------|-------------------|--------|--------|
| **DX** | Progress visualization | High | Low |
| **Quality** | Confidence scoring | High | Medium |
| **Performance** | Parallel execution | Medium | Medium |
| **Polish** | Rich terminal UI | Medium | Low |
| **Advanced** | Learning from corrections | High | High |

The biggest quick win is **progress visualization** - it costs almost nothing to implement but dramatically improves the developer experience by showing what's happening in real-time.
