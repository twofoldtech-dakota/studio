---
name: planning
description: Plan-and-Solve methodology for goal decomposition and plan creation
triggers:
  - "plan"
  - "plan"
  - "decompose"
  - "analyze goal"
  - "break down"
  - "plan-and-solve"
loop_config: data/loop-configs/planner.yaml
---

# Planning Skill: Plan-and-Solve Methodology

This skill teaches the **Plan-and-Solve** methodology for decomposing goals into executable plans. It is based on research from "Plan-and-Solve Prompting: Improving Zero-Shot Chain-of-Thought Reasoning by Large Language Models" (Wang et al., 2023).

## Loop Configuration

The planner uses the universal loop system defined in `data/loop-configs/planner.yaml`:

```yaml
loop_type: question-respond-clarify
max_iterations: 5
trigger: requirement_gathering
phases: [prepare_questions, ask_user, process_response, check_readiness,
         need_clarification, offer_proceed, ready_to_plan]
```

**Key Loop Phases:**
- **ATTEMPT (prepare_questions)**: Formulate questions for current round
- **ATTEMPT (ask_user)**: Present questions, await response
- **OBSERVE (process_response)**: Extract requirements from answers
- **EVALUATE (check_readiness)**: Determine if enough info gathered
- **RETRY (need_clarification)**: More questions needed
- **CHECKPOINT (offer_proceed)**: Ask if ready despite gaps
- **NEXT (ready_to_plan)**: Exit loop, proceed to construction

**Non-Looping Phases:**
- Context Gathering: Single pass analysis
- Challenge Phase: Single adversarial review
- Confidence Scoring: Single calculation

## The Core Insight

Most failures in complex tasks come from starting execution too early. The Plan-and-Solve methodology addresses this by enforcing thorough planning before any action is taken.

```
Traditional Approach:        Plan-and-Solve Approach:
─────────────────────        ───────────────────────

Goal → Act → Fail → Retry    Goal → Plan → Verify Plan → Act → Succeed
         ↑______|                         ↑_____|
         (loops)                          (validates)
```

## The Three Planning Phases

Plan-and-Solve operates in three distinct phases:

### Phase 1: Variable Extraction

Before planning, identify all variables in the problem:

**Inputs**: What do we have to work with?
- Existing code, files, resources
- User requirements and constraints
- Available tools and capabilities
- Time and scope limitations

**Outputs**: What must we produce?
- Files, code, configurations
- Documentation, tests
- State changes, side effects
- User-visible results

**Constraints**: What limits our approach?
- Technical constraints (language, framework)
- Architectural constraints (patterns, conventions)
- Resource constraints (time, dependencies)
- Quality constraints (tests, documentation)

**Dependencies**: What depends on what?
- External dependencies (packages, APIs)
- Internal dependencies (modules, data)
- Temporal dependencies (order of operations)
- Logical dependencies (preconditions)

### Phase 2: Intermediate Calculation

Before finalizing the plan, work through the middle:

**Gap Analysis**: What's the delta between current and desired state?
```
Current State: No user registration
Desired State: Working registration endpoint
Gap: Need schema, service, controller, route, tests
```

**Complexity Assessment**: How hard is each part?
- Trivial: Single file, known pattern
- Simple: Few files, clear approach
- Moderate: Multiple files, some decisions
- Complex: Many files, significant decisions
- Ambitious: System-wide, architectural impact

**Risk Identification**: What could go wrong?
- Technical risks (approach might not work)
- Integration risks (parts might not fit)
- External risks (dependencies might fail)
- Quality risks (might not meet standards)

**Path Selection**: Which approach is best?
- Consider multiple approaches
- Evaluate trade-offs
- Select based on constraints and risks
- Document why this path was chosen

### Phase 3: Step-by-Step Planning

Decompose into atomic, verifiable steps:

**Atomic**: Each step does exactly one thing
```
Bad:  "Create the user system"
Good: "Create User interface in src/models/user.ts with id, email, name fields"
```

**Verifiable**: Each step has clear success criteria
```
Bad:  "The model should be correct"
Good: "File exists, exports User interface, includes required fields, passes type check"
```

**Ordered**: Steps are in executable sequence
```
Step 1: Create schema (no dependencies)
Step 2: Create service (depends on schema)
Step 3: Create controller (depends on service)
Step 4: Create route (depends on controller)
```

**Recoverable**: Failed steps can be addressed
```
If step fails: Try alternative approach
If no alternative: Roll back to checkpoint
If critical: Escalate for replanning
```

## The Plan Structure

A complete plan follows this structure:

```yaml
plan:
  # HEADER - Identifies and summarizes
  id: "unique identifier"
  goal: "exact goal statement"
  created_at: "timestamp"
  estimated_complexity: "trivial|simple|moderate|complex|ambitious"

  # ANALYSIS - What we learned from variable extraction
  analysis:
    summary: "1-2 sentence approach summary"
    inputs: [list of inputs with sources]
    outputs: [list of outputs with locations]
    constraints: [list of constraints with impacts]
    risks: [list of risks with mitigations]
    assumptions: [list of assumptions made]

  # STEPS - The actual plan
  steps:
    - id: "step_1"
      name: "short name"
      action: "detailed description"
      rationale: "why this step"
      inputs: [what it needs]
      outputs: [what it produces]
      success_criteria: [how to verify]
      failure_modes: [what could go wrong]
      depends_on: [dependencies]
      tools_required: [tools needed]

  # CHECKPOINTS - Recovery points
  checkpoints:
    - after_step: "step_id"
      name: "checkpoint name"
      verification: [what to check]
      rollback_to: "step_id if failure"

  # VERIFYING CRITERIA - What must be verified
  verification_criteria:
    must_verify: [critical requirements]
    quality_checks: [quality requirements]
```

## Success Criteria Design

Well-designed success criteria are specific and verifiable:

### The SMART Framework for Criteria

**Specific**: Exactly what must be true
```
Bad:  "Code works"
Good: "registerUser function returns User object on success"
```

**Measurable**: Can be objectively checked
```
Bad:  "Good performance"
Good: "Response time under 200ms for p95"
```

**Achievable**: Actually possible to accomplish
```
Bad:  "Perfect security"
Good: "Passwords hashed with bcrypt, cost factor 10+"
```

**Relevant**: Directly relates to the goal
```
Bad:  "Beautiful code formatting"
Good: "Follows existing code style conventions"
```

**Testable**: Can be verified automatically or manually
```
Bad:  "User experience is good"
Good: "Returns 201 on success, 400 on validation failure, 409 on duplicate"
```

### Verification Methods

Each criterion should specify how to verify it:

| Criterion Type | Verification Method |
|---------------|---------------------|
| File exists | `test -f path` or Glob |
| Export exists | `grep "export"` or import test |
| Function works | Unit test execution |
| Integration works | Integration test or manual test |
| Types correct | `tsc --noEmit` |
| Style correct | Linter execution |
| Tests pass | Test runner execution |

## Risk Mitigation Strategies

For each identified risk, plan mitigation:

### Risk Matrix

```
              │ Low Impact │ Med Impact │ High Impact │
──────────────┼────────────┼────────────┼─────────────┤
Low Prob.     │   Accept   │   Monitor  │   Mitigate  │
Med Prob.     │   Monitor  │   Mitigate │   Mitigate  │
High Prob.    │   Mitigate │   Mitigate │   Avoid     │
```

### Mitigation Approaches

**Accept**: Risk is tolerable, proceed without special handling
**Monitor**: Watch for signs, have response ready
**Mitigate**: Take proactive steps to reduce likelihood or impact
**Avoid**: Change approach to eliminate the risk

### Mitigation Examples

```yaml
risk:
  description: "Email validation regex may miss edge cases"
  probability: "medium"
  impact: "low"
  strategy: "mitigate"
  mitigation: "Use established email-validator package"
  contingency: "Fall back to simple format check"
```

## Dependency Mapping

Map dependencies to ensure correct execution order:

### Dependency Types

**Data Dependencies**: Output of one step is input to another
```
step_2.input = step_1.output
Therefore: step_2 depends_on step_1
```

**Resource Dependencies**: Shared resource must be ready
```
step_3 needs database connection
step_1 creates database connection
Therefore: step_3 depends_on step_1
```

**Logical Dependencies**: One thing must be true first
```
step_4 tests the API
step_3 creates the API
Therefore: step_4 depends_on step_3
```

### Dependency Visualization

```
step_1 ──┬──→ step_2 ──→ step_4
         │              ↗
         └──→ step_3 ──┘
```

Read as:
- step_2 depends on step_1
- step_3 depends on step_1
- step_4 depends on step_2 AND step_3

### Avoiding Circular Dependencies

Circular dependencies indicate a planning error:
```
step_1 → step_2 → step_3 → step_1  ← ERROR
```

Resolution:
1. Identify the cycle
2. Break it by splitting a step
3. Or reorder to eliminate the cycle

## Checkpoint Design

Checkpoints enable recovery and progress verification:

### When to Place Checkpoints

- After completing a logical unit of work
- Before high-risk steps
- At natural pause points
- After irreversible operations

### Checkpoint Structure

```yaml
checkpoint:
  after_step: "step_3"
  name: "Core implementation complete"
  description: "All business logic is in place"
  verification:
    - "Schema file exists and exports correctly"
    - "Service file exists and all methods work"
    - "Controller file exists and handles requests"
  rollback_to: "step_1"  # Where to restart if later steps fail
  state_to_preserve:
    - "All files created in steps 1-3"
    - "Any configuration changes"
```

### Checkpoint Benefits

1. **Recovery**: Can restart from checkpoint instead of beginning
2. **Verification**: Confirms partial progress
3. **Communication**: Shows progress to user
4. **Debugging**: Isolates where things went wrong

## Common Planning Pitfalls

### Pitfall 1: Vague Steps

```
Bad:  "Set up the database"
Good: "Create PostgreSQL migration at db/migrations/001_create_users.sql
       defining users table with columns: id (UUID), email (VARCHAR 255),
       password_hash (VARCHAR 255), created_at (TIMESTAMP)"
```

### Pitfall 2: Missing Dependencies

```
Bad:  Step 3 needs config that Step 5 creates
Good: Reorder so Step 5 comes before Step 3, or add explicit dependency
```

### Pitfall 3: Unverifiable Criteria

```
Bad:  "Code is clean and well-organized"
Good: "Passes eslint with zero errors, follows existing naming conventions"
```

### Pitfall 4: No Failure Handling

```
Bad:  No failure_modes specified
Good: Each step lists what could go wrong and how to recover
```

### Pitfall 5: Over-Planning

```
Bad:  50 steps for a simple feature
Good: Minimum steps needed, no unnecessary granularity
```

## The Planning Mindset

When planing, adopt this mindset:

1. **Be thorough, not paranoid** - Cover important cases, not every edge case
2. **Be specific, not verbose** - Precise language, minimum words
3. **Be realistic, not optimistic** - Plan for what usually happens
4. **Be adaptive, not rigid** - The plan should guide, not constrain
5. **Be complete, not exhaustive** - Everything needed, nothing extra

## Questioning Loop State

The questioning loop state is tracked for recovery:

```yaml
# .studio/tasks/{task_id}/questioning_state.json
questioning_state:
  loop_id: "loop_questioning_1706789123"
  config_name: "planner-questioning"
  current_iteration: 2
  current_phase: "check_readiness"
  status: "running"

  round_history:
    - round: 1
      focus: "scope_and_success"
      questions_asked: 3
      answers_received: 3
      requirements_extracted: 5
    - round: 2
      focus: "technical_constraints"
      questions_asked: 3
      answers_received: 2
      requirements_extracted: 3

  gathered_requirements:
    scope_in: ["feature A", "feature B"]
    scope_out: ["feature X"]
    success_criteria: ["criterion 1", "criterion 2"]
    technical_constraints: ["use existing auth"]

  readiness_score: 0.65
  missing_items: ["edge case handling", "performance requirements"]
```

### Questioning Checkpoints

Checkpoints are saved after each questioning round:

```bash
# After each round, check readiness and optionally checkpoint
if readiness_score >= 0.7; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/orchestrator.sh" checkpoint "questioning_complete"
fi
```

## Verification Questions

Before finalizing a plan, ask:

- [ ] Could someone else execute this plan without asking questions?
- [ ] Is every step verifiable with clear criteria?
- [ ] Are all dependencies mapped correctly?
- [ ] Are risks identified with mitigations?
- [ ] Are checkpoints at logical recovery points?
- [ ] Does the plan match the original goal exactly?
- [ ] Is the verifying criteria complete and specific?

If any answer is "no," refine the plan.

---

## Enterprise Decomposition

For large-scale projects (10+ tasks, enterprise migrations, complex multi-pillar work), use the Enterprise Decomposition system. This ensures tasks remain atomic, context is preserved across 50+ tasks, and quality gates are enforced.

### When to Use Enterprise Decomposition

Trigger enterprise decomposition when:
- Project has more than 10 estimated tasks
- Project spans multiple architectural pillars
- Project is a migration (Sitecore, CMS, legacy system)
- Project requires strict compliance (WCAG, SOC2, HIPAA)
- Multiple developers will work on the project

### The 6 Architectural Pillars

Every project is analyzed across 6 pillars:

| Pillar | Scope | Examples |
|--------|-------|----------|
| **data_schema** | Data models, migrations, relationships | Prisma schemas, DB migrations, entity design |
| **auth** | Identity, sessions, permissions | OAuth, JWT, RBAC, session management |
| **api** | Endpoints, middleware, contracts | REST routes, GraphQL resolvers, API versioning |
| **ui_ux** | Components, layouts, state, a11y | React components, CSS, accessibility |
| **integration** | External services, CMS, search | Sitecore, Algolia, analytics, payment APIs |
| **infra_devops** | CI/CD, environments, monitoring | GitHub Actions, Docker, logging, scaling |

Score each pillar 0-100 based on relevance to the project.

### SICVF Atomic Task Criteria

Every task must pass SICVF validation:

```
SICVF Validation
================

S - Single-pass
   ✓ < 8 hours estimated work
   ✓ < 15 micro-actions (tool calls, edits, commands)
   ✗ FAIL: Split the task

I - Independent
   ✓ All depends_on tasks are COMPLETE
   ✓ No concurrent dependencies
   ✗ FAIL: Reorder or wait

C - Clear boundaries
   ✓ Explicit inputs defined
   ✓ Explicit outputs defined
   ✓ No "undefined" or "TBD" sources
   ✗ FAIL: Define boundaries

V - Verifiable
   ✓ All acceptance criteria have verification commands
   ✓ Success can be objectively measured
   ✗ FAIL: Add executable criteria

F - Fits context
   ✓ Task + context < 80K tokens
   ✓ Can fit in single Claude session
   ✗ FAIL: Split or summarize context
```

Run validation:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/sicvf-validate.sh" --task-id <task_id>
"${CLAUDE_PLUGIN_ROOT}/scripts/sicvf-validate.sh" --all
```

### 4-Tier Context Preservation

For long-running projects, context is managed across 4 tiers:

```
Tier 0: Invariants (5K tokens, NEVER aged)
├── Architectural decisions (AD-001, AD-002...)
├── Constraints (CON-001, CON-002...)
├── Patterns (PAT-001, PAT-002...)
└── Conventions (CNV-001, CNV-002...)

Tier 1: Active Context (30K tokens, last 5 tasks)
├── Current task plan
├── Previous task summary
├── Next task preview
└── Recent learnings (domain-relevant)

Tier 2: Summarized (15K tokens, tasks 6-20)
├── Compressed task summaries
├── Pattern registry
└── Error resolution history

Tier 3: Indexed (5K tokens, tasks 21+)
├── Task ID → name mapping
├── File → task history
└── Dependency cross-references
```

Inject context:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/context-inject.sh" --task-id <task_id> --goal "<goal>"
```

### Definition of Done Templates

Four DoD templates are available:

| Template | Extends | Key Checks |
|----------|---------|------------|
| `universal` | - | lint, typecheck, test, npm audit, secretlint |
| `frontend` | universal | + axe-core, Lighthouse a11y/perf >= 90, LCP <= 2.5s, CLS <= 0.1 |
| `backend` | universal | + Zod validation, auth middleware, SQL injection prevention |
| `api-endpoint` | universal | + OpenAPI docs, contract tests, CORS, pagination |

Assign based on task type:
- UI/component work → `frontend`
- API endpoint creation → `api-endpoint`
- Service/data layer → `backend`
- Everything else → `universal`

### Decomposition Map Output

Before any code generation, enterprise decomposition outputs:

```json
{
  "decomposition_map": {
    "pillar_analysis": { /* 6 pillars with scores */ },
    "hierarchy": {
      "epics": [],
      "features": [],
      "tasks": []
    },
    "dependency_graph": {
      "nodes": [],
      "edges": [],
      "critical_path": [],
      "parallel_batches": []
    },
    "context_plan": {
      "invariants": [],
      "injection_strategy": {}
    },
    "quality_config": {
      "dod_assignments": {},
      "blocking_thresholds": {}
    }
  }
}
```

**This map requires user approval before execution begins.**

### Enterprise Decomposition Checklist

Before proceeding to execution:

- [ ] Pillar analysis complete with scores 0-100
- [ ] All tasks have SICVF validation passing
- [ ] No task exceeds 8 hours or 15 micro-actions
- [ ] Dependency graph has no cycles
- [ ] Critical path identified
- [ ] Parallel batches defined
- [ ] Invariants extracted to `studio/context/invariants.md`
- [ ] DoD templates assigned to all tasks
- [ ] Quality thresholds configured
- [ ] User has approved the decomposition map

---

*"A plan that cannot be verified is not a plan—it's a hope." - Planning Principle*

*"Decompose completely, execute atomically, preserve context always." - Enterprise Decomposition Principle*
