# STUDIO Workflow Visual Guide

A complete visual overview of how STUDIO coordinates AI agents to build software.

---

## The Big Picture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                              USER REQUEST                                       │
│                          /build "Add auth"                                      │
│                                  │                                              │
│                                  ▼                                              │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         THE ORCHESTRATOR                                   │  │
│  │                    (The Traffic Controller)                               │  │
│  │                                                                           │  │
│  │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐  │  │
│  │   │   ROUTE     │ → │   ATTACH    │ → │  EXECUTE    │ → │  RECOVER    │  │  │
│  │   │   Request   │   │   Skills    │   │   Agents    │   │  Failures   │  │  │
│  │   └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                  │                                              │
│                    ┌─────────────┴─────────────┐                               │
│                    ▼                           ▼                               │
│  ┌─────────────────────────────┐   ┌─────────────────────────────┐            │
│  │       THE PLANNER           │   │       THE BUILDER           │            │
│  │    Creates the Blueprint    │ → │   Executes the Blueprint    │            │
│  │                             │   │                             │            │
│  │  • Gathers requirements     │   │  • Writes code              │            │
│  │  • Asks questions           │   │  • Runs tests               │            │
│  │  • Validates plan           │   │  • Fixes errors             │            │
│  │  • Outputs: plan.json       │   │  • Captures learnings       │            │
│  └─────────────────────────────┘   └─────────────────────────────┘            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Flow

### 1. Request Entry

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  USER COMMANDS                                                  │
│  ─────────────                                                  │
│                                                                 │
│  /plan "goal"       → Planning only, no execution               │
│  /build "goal"      → Full workflow (plan if needed + build)    │
│  /orchestrate       → Explicit control, visible decisions       │
│                                                                 │
│  Examples:                                                      │
│  ├── /build "Add login page"                                    │
│  ├── /build --task task_123      (resume existing task)         │
│  └── /orchestrate build "Complex feature"                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Goal Analysis & Routing

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ORCHESTRATOR ANALYZES GOAL                                     │
│  ─────────────────────────────                                  │
│                                                                 │
│  "Add OAuth login with Google and GitHub"                       │
│                     │                                           │
│                     ▼                                           │
│  ┌───────────────────────────────────────────┐                  │
│  │  COMPLEXITY DETECTION                      │                  │
│  │                                           │                  │
│  │  Keywords found: "OAuth", "login"         │                  │
│  │  Multi-part goal: YES (Google + GitHub)   │                  │
│  │  New feature: YES                         │                  │
│  │                                           │                  │
│  │  VERDICT: COMPLEX → Needs Planning        │                  │
│  └───────────────────────────────────────────┘                  │
│                     │                                           │
│                     ▼                                           │
│  ┌───────────────────────────────────────────┐                  │
│  │  WORKFLOW SELECTION                        │                  │
│  │                                           │                  │
│  │  ○ build_only      (simple fixes)         │                  │
│  │  ● plan_then_build (features) ← SELECTED  │                  │
│  │  ○ multi_task      (backlog execution)    │                  │
│  │  ○ decompose       (epic breakdown)       │                  │
│  └───────────────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Skill Attachment

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  SKILL DETECTION                                                │
│  ───────────────                                                │
│                                                                 │
│  Goal: "Add OAuth login"                                        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  AVAILABLE SKILLS                                        │    │
│  │                                                         │    │
│  │  security.yaml     │ Keywords: "auth", "login", "OAuth" │    │
│  │  backend.yaml      │ Keywords: "API", "endpoint"        │    │
│  │  frontend.yaml     │ Keywords: "UI", "component"        │    │
│  │  testing.yaml      │ Keywords: "test", "coverage"       │    │
│  │  data.yaml         │ Keywords: "database", "privacy"    │    │
│  │  accessibility.yaml│ Keywords: "a11y", "screen reader"  │    │
│  │  performance.yaml  │ Keywords: "optimize", "speed"      │    │
│  │  devops.yaml       │ Keywords: "deploy", "CI/CD"        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  MATCHED SKILLS                                          │    │
│  │                                                         │    │
│  │  ✓ security  (score: 30) ← "login", "OAuth" matched     │    │
│  │  ✓ backend   (score: 15) ← API patterns detected        │    │
│  │  ✗ frontend  (score: 5)  ← below threshold              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Skills inject:                                                 │
│  • Additional questions to ask                                  │
│  • Guidelines to follow                                         │
│  • Team members to consult                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4. The Planner Phase

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║                      THE PLANNER                          ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                 │
│  PHASE 1: CONTEXT GATHERING                                     │
│  ─────────────────────────────                                  │
│                                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │ Load    │  │ Scan    │  │ Check   │  │ Query   │            │
│  │Learnings│  │Codebase │  │ Git     │  │Context7 │            │
│  │         │  │         │  │ Status  │  │  (MCP)  │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
│       │            │            │            │                  │
│       └────────────┴────────────┴────────────┘                  │
│                         │                                       │
│                         ▼                                       │
│               ┌─────────────────┐                               │
│               │ CONTEXT READY   │                               │
│               └─────────────────┘                               │
│                                                                 │
│  PHASE 2: ITERATIVE QUESTIONING                                 │
│  ────────────────────────────────                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  QUESTION LOOP (max 5 rounds)                              │  │
│  │                                                           │  │
│  │  Round 1: Scope & Success                                 │  │
│  │  ┌────────────────────────────────────────────────────┐   │  │
│  │  │ "Which OAuth providers: Google, GitHub, or both?"  │   │  │
│  │  │ "Should users be able to link multiple accounts?"  │   │  │
│  │  └────────────────────────────────────────────────────┘   │  │
│  │              ▼                                            │  │
│  │  ┌────────────────┐                                       │  │
│  │  │ User Responds  │                                       │  │
│  │  └────────────────┘                                       │  │
│  │              ▼                                            │  │
│  │  Round 2: Technical Constraints                           │  │
│  │  ┌────────────────────────────────────────────────────┐   │  │
│  │  │ "Where should OAuth tokens be stored?"             │   │  │
│  │  │ "What happens if OAuth fails mid-flow?"            │   │  │
│  │  └────────────────────────────────────────────────────┘   │  │
│  │              ▼                                            │  │
│  │  Ready to proceed? ────YES────▶ Exit Loop                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  PHASE 3: PLAN CONSTRUCTION                                     │
│  ───────────────────────────                                    │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  OUTPUT: plan.json                                        │  │
│  │                                                           │  │
│  │  {                                                        │  │
│  │    "goal": "Add OAuth login...",                          │  │
│  │    "acceptance_criteria": [                               │  │
│  │      { "criterion": "Google login works", "type": "e2e" } │  │
│  │    ],                                                     │  │
│  │    "steps": [                                             │  │
│  │      { "id": "step_1", "name": "Create OAuth config" },   │  │
│  │      { "id": "step_2", "name": "Implement Google" },      │  │
│  │      { "id": "step_3", "name": "Implement GitHub" },      │  │
│  │      { "id": "step_4", "name": "Write tests" }            │  │
│  │    ],                                                     │  │
│  │    "quality_gates": { "lint": true, "test": true }        │  │
│  │  }                                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  VALIDATION                                                     │
│  ──────────                                                     │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  THE FIVE CHALLENGES                                      │  │
│  │                                                           │  │
│  │  1. REQUIREMENTS  ✓  All requirements mapped to steps     │  │
│  │  2. EDGE CASES    ✓  OAuth failures handled               │  │
│  │  3. SIMPLICITY    ✓  Minimal steps for goal               │  │
│  │  4. INTEGRATION   ✓  Follows existing auth patterns       │  │
│  │  5. FAILURE MODES ✓  Rollback strategy defined            │  │
│  │                                                           │  │
│  │  CONFIDENCE SCORE: 87% ████████░░                         │  │
│  │  VERDICT: APPROVED                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5. Handoff to Builder

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ORCHESTRATOR HANDOFF                                           │
│  ────────────────────                                           │
│                                                                 │
│       PLANNER                           BUILDER                 │
│          │                                 │                    │
│          │    ┌─────────────────────┐      │                    │
│          ├───▶│  HANDOFF PACKAGE    │─────▶│                    │
│          │    │                     │      │                    │
│          │    │  • task_id          │      │                    │
│          │    │  • plan.json        │      │                    │
│          │    │  • active_skills    │      │                    │
│          │    │  • context_summary  │      │                    │
│          │    │  • team_loaded      │      │                    │
│          │    └─────────────────────┘      │                    │
│          │                                 │                    │
│          ▼                                 ▼                    │
│     [COMPLETE]                        [STARTING]                │
│                                                                 │
│  Checkpoint saved: "planning_complete"                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6. The Builder Phase

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║                      THE BUILDER                          ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                 │
│  THE EXECUTE-OBSERVE-DECIDE LOOP                                │
│  ───────────────────────────────                                │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  FOR EACH STEP IN PLAN:                                   │  │
│  │                                                           │  │
│  │      ┌──────────┐                                         │  │
│  │      │ EXECUTE  │  Write code, create files               │  │
│  │      └────┬─────┘                                         │  │
│  │           │                                               │  │
│  │           ▼                                               │  │
│  │      ┌──────────┐                                         │  │
│  │      │ OBSERVE  │  Run validation command                 │  │
│  │      └────┬─────┘                                         │  │
│  │           │                                               │  │
│  │      ┌────┴────┐                                          │  │
│  │      ▼         ▼                                          │  │
│  │   ┌─────┐  ┌──────┐                                       │  │
│  │   │PASS │  │ FAIL │                                       │  │
│  │   └──┬──┘  └──┬───┘                                       │  │
│  │      │        │                                           │  │
│  │      │        ▼                                           │  │
│  │      │   ┌──────────┐                                     │  │
│  │      │   │ DECIDE   │                                     │  │
│  │      │   └────┬─────┘                                     │  │
│  │      │        │                                           │  │
│  │      │   ┌────┴────┬──────────┐                           │  │
│  │      │   ▼         ▼          ▼                           │  │
│  │      │ RETRY    REPLAN     ESCALATE                       │  │
│  │      │ (≤5x)   (modify)   (to user)                       │  │
│  │      │   │         │                                      │  │
│  │      │   └────┬────┘                                      │  │
│  │      │        │                                           │  │
│  │      ▼        ▼                                           │  │
│  │   ┌─────────────┐                                         │  │
│  │   │ NEXT STEP   │                                         │  │
│  │   └─────────────┘                                         │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  EXAMPLE EXECUTION:                                             │
│  ──────────────────                                             │
│                                                                 │
│  Step 1/4: Create OAuth config                                  │
│  ├── EXECUTE: Write src/auth/oauth.config.ts                    │
│  ├── OBSERVE: npx tsc --noEmit                                  │
│  └── RESULT: ✓ PASS                                             │
│                                                                 │
│  Step 2/4: Implement Google OAuth                               │
│  ├── EXECUTE: Write src/auth/providers/google.ts                │
│  ├── OBSERVE: npm test -- google                                │
│  ├── RESULT: ✗ FAIL (missing env var)                           │
│  ├── DECIDE: RETRY                                              │
│  ├── EXECUTE: Add GOOGLE_CLIENT_ID check                        │
│  ├── OBSERVE: npm test -- google                                │
│  └── RESULT: ✓ PASS                                             │
│                                                                 │
│  QUALITY GATES                                                  │
│  ─────────────                                                  │
│                                                                 │
│  After all steps complete:                                      │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  ✓ Lint:      npm run lint                                │  │
│  │  ✓ Typecheck: npx tsc --noEmit                            │  │
│  │  ✓ Tests:     npm test                                    │  │
│  │  ✓ Security:  npm audit                                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  LEARNING CAPTURE                                               │
│  ────────────────                                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  New learning detected:                                   │  │
│  │  "OAuth providers need env var validation at startup"     │  │
│  │                                                           │  │
│  │  Saved to: studio/learnings/security.md                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7. Completion

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║                      COMPLETE                             ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  TASK SUMMARY                                             │  │
│  │  ────────────                                             │  │
│  │                                                           │  │
│  │  Goal:    Add OAuth login with Google and GitHub          │  │
│  │  Status:  COMPLETE                                        │  │
│  │  Task ID: task_20260202_143052                            │  │
│  │                                                           │  │
│  │  FILES CREATED:                                           │  │
│  │  ├── src/auth/oauth.config.ts                             │  │
│  │  ├── src/auth/providers/google.ts                         │  │
│  │  ├── src/auth/providers/github.ts                         │  │
│  │  ├── src/auth/middleware.ts                               │  │
│  │  └── tests/auth/oauth.test.ts                             │  │
│  │                                                           │  │
│  │  QUALITY:                                                 │  │
│  │  ├── All acceptance criteria: PASSED                      │  │
│  │  ├── All quality gates: PASSED                            │  │
│  │  └── Learnings captured: 2 new rules                      │  │
│  │                                                           │  │
│  │  SKILLS USED:                                             │  │
│  │  ├── security (consulted: security-analyst)               │  │
│  │  └── backend (consulted: backend-specialist)              │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Failure Recovery Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  WHEN THINGS GO WRONG                                           │
│  ────────────────────                                           │
│                                                                 │
│                    FAILURE DETECTED                             │
│                          │                                      │
│                          ▼                                      │
│               ┌─────────────────────┐                           │
│               │ Is it recoverable?  │                           │
│               └──────────┬──────────┘                           │
│                          │                                      │
│              ┌───────────┴───────────┐                          │
│              ▼                       ▼                          │
│            YES                      NO                          │
│              │                       │                          │
│              ▼                       ▼                          │
│   ┌─────────────────────┐  ┌─────────────────────┐              │
│   │ Retries remaining?  │  │   Is it critical?   │              │
│   └──────────┬──────────┘  └──────────┬──────────┘              │
│              │                        │                         │
│    ┌─────────┴─────────┐    ┌─────────┴─────────┐               │
│    ▼                   ▼    ▼                   ▼               │
│   YES                  NO  YES                  NO              │
│    │                   │    │                   │               │
│    ▼                   ▼    ▼                   ▼               │
│ ┌──────┐          ┌────────┐ ┌────────┐    ┌────────┐          │
│ │RETRY │          │REPLAN  │ │ESCALATE│    │  SKIP  │          │
│ │(same │          │(modify │ │(ask    │    │(continue│          │
│ │step) │          │ plan)  │ │ user)  │    │ w/o it)│          │
│ └──────┘          └────────┘ └────────┘    └────────┘          │
│                                                                 │
│  CHECKPOINT SYSTEM:                                             │
│  ──────────────────                                             │
│                                                                 │
│  Before each major phase, a checkpoint is saved:                │
│                                                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐      │
│  │ CP: 1   │ →  │ CP: 2   │ →  │ CP: 3   │ →  │ CP: 4   │      │
│  │planning │    │plan     │    │step_2   │    │quality  │      │
│  │_start   │    │_complete│    │_complete│    │_gates   │      │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘      │
│                                                                 │
│  Resume from any checkpoint:                                    │
│  /orchestrate resume cp_1706789456                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Components

### Agents

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  THE THREE CORE AGENTS                                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                     ORCHESTRATOR                          │  │
│  │                    (meta-agent)                           │  │
│  │                                                           │  │
│  │  • Routes requests to correct agent                       │  │
│  │  • Attaches relevant skills                               │  │
│  │  • Manages state & checkpoints                            │  │
│  │  • Handles failures                                       │  │
│  │  • Coordinates handoffs                                   │  │
│  │                                                           │  │
│  │  Color: Magenta       Playbook: orchestration             │  │
│  └───────────────────────────────────────────────────────────┘  │
│                          │                                      │
│            ┌─────────────┴─────────────┐                       │
│            ▼                           ▼                       │
│  ┌─────────────────────┐     ┌─────────────────────┐           │
│  │      PLANNER        │     │      BUILDER        │           │
│  │                     │     │                     │           │
│  │  • Gathers context  │     │  • Executes plans   │           │
│  │  • Asks questions   │     │  • Writes code      │           │
│  │  • Creates plans    │     │  • Runs tests       │           │
│  │  • Validates plans  │     │  • Fixes errors     │           │
│  │                     │     │  • Captures learns  │           │
│  │  Color: Blue        │     │  Color: Gold        │           │
│  │  Playbook: planning │     │  Playbook: building │           │
│  └─────────────────────┘     └─────────────────────┘           │
│                                                                 │
│  SUPPORTING AGENT                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   CONTENT WRITER                          │  │
│  │                                                           │  │
│  │  • Creates brand-aligned content                          │  │
│  │  • Blog posts, marketing copy                             │  │
│  │  • Invoked via /blog or /brand commands                   │  │
│  │                                                           │  │
│  │  Color: Purple        Playbooks: brand, content           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Skills

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  SKILL SYSTEM                                                   │
│  ────────────                                                   │
│                                                                 │
│  Skills enrich agents with domain-specific guidance             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────┐ │    │
│  │  │ security  │ │ backend   │ │ frontend  │ │ testing │ │    │
│  │  │           │ │           │ │           │ │         │ │    │
│  │  │ • OAuth   │ │ • APIs    │ │ • UI/UX   │ │ • Unit  │ │    │
│  │  │ • Encrypt │ │ • DB      │ │ • A11y    │ │ • E2E   │ │    │
│  │  │ • Auth    │ │ • Services│ │ • React   │ │ • Mocks │ │    │
│  │  └───────────┘ └───────────┘ └───────────┘ └─────────┘ │    │
│  │                                                         │    │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────┐ │    │
│  │  │   data    │ │performance│ │  devops   │ │  a11y   │ │    │
│  │  │           │ │           │ │           │ │         │ │    │
│  │  │ • Privacy │ │ • Caching │ │ • CI/CD   │ │ • WCAG  │ │    │
│  │  │ • GDPR    │ │ • Lazy    │ │ • Docker  │ │ • ARIA  │ │    │
│  │  │ • Encrypt │ │ • Bundle  │ │ • K8s     │ │ • Focus │ │    │
│  │  └───────────┘ └───────────┘ └───────────┘ └─────────┘ │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Each skill provides:                                           │
│  • Trigger keywords for auto-detection                          │
│  • Questions to ask during planning                             │
│  • Guidelines to follow during building                         │
│  • Team members to consult                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Playbooks

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  PLAYBOOKS (Methodologies)                                      │
│  ─────────────────────────                                      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  CORE PLAYBOOKS                                          │   │
│  │                                                          │   │
│  │  planning/       Plan-and-Solve methodology              │   │
│  │                  • Variable extraction                   │   │
│  │                  • Intermediate calculation              │   │
│  │                  • Step-by-step planning                 │   │
│  │                                                          │   │
│  │  building/       Plan-and-Execute methodology            │   │
│  │                  • Execute-Observe-Decide loop           │   │
│  │                  • Retry protocols                       │   │
│  │                  • Checkpoint management                 │   │
│  │                                                          │   │
│  │  validation/     Challenge + Confidence scoring          │   │
│  │                  • Five challenges                       │   │
│  │                  • Quality scoring                       │   │
│  │                                                          │   │
│  │  reviewing/      Reflection methodology                  │   │
│  │                  • Verify work against requirements      │   │
│  │                  • Identify gaps                         │   │
│  │                  • Render verdicts                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  SUPPORTING PLAYBOOKS                                    │   │
│  │                                                          │   │
│  │  orchestration/       Multi-agent coordination           │   │
│  │  context-management/  Token budget optimization          │   │
│  │  memory/              Learning system                    │   │
│  │  brand/               Brand discovery                    │   │
│  │  content/             Content creation                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Team Members

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  TEAM PERSONAS (Domain Experts)                                 │
│  ──────────────────────────────                                 │
│                                                                 │
│  Loaded by skills to provide domain expertise                   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  TIER 1: Core Specialists (frequently consulted)         │   │
│  │                                                          │   │
│  │  orchestrator       business-analyst    tech-lead        │   │
│  │  frontend-specialist backend-specialist brand-strategist │   │
│  │  ui-ux-designer                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  TIER 2: Quality Specialists                             │   │
│  │                                                          │   │
│  │  qa-refiner         security-analyst    devops-engineer  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  TIER 3: Growth Specialists                              │   │
│  │                                                          │   │
│  │  legal-compliance   seo-growth                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  COMMAND CHEAT SHEET                                            │
│                                                                 │
│  /plan "goal"           Create a plan (no execution)            │
│  /build "goal"          Full workflow (plan + build)            │
│  /build --task ID       Resume a specific task                  │
│  /orchestrate           Show orchestration status               │
│  /orchestrate build     Build with visible routing              │
│  /orchestrate resume    Resume from checkpoint                  │
│  /status                Show project status                     │
│  /brand                 Brand discovery interview               │
│  /blog                  Create brand-aligned blog post          │
│                                                                 │
│  FILE LOCATIONS                                                 │
│                                                                 │
│  .studio/tasks/[id]/plan.json     Task plans                    │
│  .studio/orchestration/[id]/      Orchestration state           │
│  studio/learnings/*.md            Captured learnings            │
│  brand/                           Brand identity files          │
│                                                                 │
│  WORKFLOW TYPES                                                 │
│                                                                 │
│  build_only        Simple fix → Builder only                    │
│  plan_then_build   Feature → Planner → Builder                  │
│  multi_task        Backlog → Builder (loop)                     │
│  decompose         Epic → Architect → Planner                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

*Built with precision. Executed with confidence. Learned continuously.*
