# STUDIO Complete Guide

> **S**elf-**T**eaching **U**nified **D**evelopment & **I**ntelligent **O**rchestration

A Claude Code plugin that transforms goals into verified outcomes through intelligent planning, autonomous execution, and continuous learning.

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [System Architecture](#system-architecture)
4. [The Three Agents](#the-three-agents)
5. [Commands Reference](#commands-reference)
6. [The Hook System](#the-hook-system)
7. [Playbooks & Methodologies](#playbooks--methodologies)
8. [The Team System](#the-team-system)
9. [Memory System](#memory-system)
10. [Quality Assurance](#quality-assurance)
11. [Advanced Features](#advanced-features)
12. [File Reference](#file-reference)

---

## Overview

### What is STUDIO?

STUDIO is an AI-powered development system that:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   🎯 GOAL                    📋 PLAN                    ✅ VERIFIED     │
│                                                                         │
│   "Add user            ──────────────────────►      Working code        │
│    authentication"          Autonomous               with tests         │
│                             Execution                 passing           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Core Philosophy

```
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   "Plan thoroughly, execute precisely, learn continuously"            ║
║                                                                       ║
║   • Every plan is CHALLENGED before execution                         ║
║   • Every step has EXECUTABLE validation                              ║
║   • Every preference is REMEMBERED for future use                     ║
║   • Every requirement is TRACEABLE to implementation                  ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Key Benefits

| Feature | Description |
|---------|-------------|
| 🧠 **Intelligent Planning** | Domain experts question requirements thoroughly |
| 🔄 **Self-Correcting** | Automatic retry with embedded fix hints |
| 📚 **Learning Memory** | Remembers your preferences across sessions |
| ✅ **Quality Gates** | Automated validation before completion |
| 🎨 **Brand Alignment** | Content stays consistent with your brand |
| ↩️ **Rollback Support** | Git-based recovery to any task state |

---

## Quick Start

### Installation

```bash
# Clone into your project
git clone <studio-repo> .claude

# Or add as Claude Code plugin
claude plugin add studio
```

### Your First Build

```bash
# Start a build with a goal
/build "Add user registration with email verification"
```

STUDIO will:
1. **Ask clarifying questions** about your requirements
2. **Create an execution-ready plan** with atomic steps
3. **Challenge the plan** for edge cases and risks
4. **Execute each step** with validation
5. **Run quality gates** before completion

### Your First Brand Setup

```bash
# Initialize brand discovery
/brand

# This starts a 5-phase interview:
# 1. Identity (mission, vision, values)
# 2. Audience (who you serve)
# 3. Voice (how you sound)
# 4. Positioning (how you're different)
# 5. Messaging (what you say)
```

---

## System Architecture

### High-Level Flow

```
                                    STUDIO SYSTEM
    ┌────────────────────────────────────────────────────────────────────┐
    │                                                                    │
    │   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌─────────┐  │
    │   │          │     │          │     │          │     │         │  │
    │   │   USER   │────▶│ PLANNER  │────▶│ BUILDER  │────▶│ VERIFIED│  │
    │   │   GOAL   │     │  AGENT   │     │  AGENT   │     │  OUTPUT │  │
    │   │          │     │          │     │          │     │         │  │
    │   └──────────┘     └────┬─────┘     └────┬─────┘     └─────────┘  │
    │                         │                │                        │
    │                    ┌────┴────────────────┴────┐                   │
    │                    │                          │                   │
    │              ┌─────┴─────┐            ┌───────┴───────┐           │
    │              │           │            │               │           │
    │              │  MEMORY   │            │    HOOKS      │           │
    │              │  SYSTEM   │            │    SYSTEM     │           │
    │              │           │            │               │           │
    │              └───────────┘            └───────────────┘           │
    │                                                                    │
    └────────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
studio/
│
├── 🤖 agents/                    # Agent Definitions
│   ├── planner.yaml             # The Planner (creates plans)
│   ├── builder.yaml             # The Builder (executes plans)
│   └── content-writer.yaml      # The Content Writer (creates content)
│
├── 📋 commands/                  # Available Commands
│   ├── build.md                 # /build command
│   ├── brand.md                 # /brand command
│   ├── blog.md                  # /blog command
│   ├── orchestrate.md           # /orchestrate command
│   └── status.md                # /status command
│
├── 📚 playbooks/                 # Methodologies (How to Think)
│   ├── planning/                # Plan-and-Solve methodology
│   ├── building/                # Execution methodology
│   ├── validation/              # Adversarial review + confidence scoring
│   ├── memory/                  # Learning system
│   ├── brand/                   # Brand discovery
│   ├── content/                 # Content creation
│   ├── reviewing/               # Self-review (Reflection methodology)
│   ├── orchestration/           # Multi-agent coordination
│   └── context-management/      # Context optimization
│
├── 👥 team/                      # Domain Expert Personas
│   ├── tier1/                   # Core specialists (always loaded)
│   │   ├── orchestrator.md      # Scope & priorities
│   │   ├── business-analyst.md  # Requirements
│   │   ├── tech-lead.md         # Architecture
│   │   ├── frontend-specialist.md
│   │   ├── backend-specialist.md
│   │   ├── ui-ux-designer.md
│   │   └── brand-strategist.md
│   ├── tier2/                   # Quality specialists
│   │   ├── qa-refiner.md        # Testing
│   │   ├── security-analyst.md  # Security
│   │   └── devops-engineer.md   # Operations
│   └── tier3/                   # Growth specialists
│       ├── legal-compliance.md
│       └── seo-growth.md
│
├── 🔗 hooks/                     # Lifecycle Hooks
│   └── hooks.json               # Hook definitions
│
├── 📐 schemas/                   # Validation Schemas
│   ├── execution-ready-plan.schema.json
│   ├── task-manifest.schema.json
│   ├── brand.schema.json
│   ├── backlog.schema.json
│   ├── confidence.schema.json
│   └── build-output.schema.json
│
├── 🎨 brand/                     # Brand Source of Truth
│   ├── identity.yaml            # Who you are
│   ├── voice.yaml               # How you sound
│   ├── audiences/               # Who you serve
│   └── messaging/               # What you say
│
├── 🔧 scripts/                   # Runtime Scripts
│   ├── output.sh                # Terminal formatting
│   ├── backlog.sh               # Backlog management
│   ├── learnings.sh             # Learning capture
│   ├── orchestrator.sh          # Multi-agent orchestration
│   └── context-manager.sh       # Context optimization
│
├── 📊 data/                      # Static Data
│   └── error-patterns.json      # Error classification
│
├── 📝 templates/                 # Code Templates
│   ├── api-endpoint.json
│   └── react-component.json
│
└── 💾 studio/                    # Runtime Data (generated)
    ├── projects/                # Project data
    │   └── [project_id]/
    │       └── tasks/
    │           └── [task_id]/
    │               ├── plan.json
    │               └── manifest.json
    ├── rules/                   # Memory rules
    │   ├── global.md
    │   ├── frontend.md
    │   └── ...
    └── data/
        ├── analytics.json
        └── snapshots.json
```

---

## The Three Agents

STUDIO uses specialized agents for different phases of work:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           THE THREE AGENTS                              │
├─────────────────────┬─────────────────────┬─────────────────────────────┤
│                     │                     │                             │
│   🔵 THE PLANNER    │   🟡 THE BUILDER    │   🟣 THE CONTENT WRITER     │
│                     │                     │                             │
│   Creates plans     │   Executes plans    │   Creates content           │
│   Embeds context    │   Follows exactly   │   Applies brand voice       │
│   Challenges self   │   Validates each    │   Optimizes for SEO         │
│                     │   step              │                             │
│                     │                     │                             │
│   Phase Color:      │   Phase Color:      │   Phase Color:              │
│   BLUE              │   GOLD              │   PURPLE                    │
│                     │                     │                             │
└─────────────────────┴─────────────────────┴─────────────────────────────┘
```

### 🔵 The Planner

**Mission:** Create execution-ready plans so comprehensive that execution becomes a single fluid motion.

```
                           PLANNER WORKFLOW
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
    │   PHASE -1                 ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  📚 PLAYBOOK LOAD                           │       │
    │   │  Load: planning, memory, challenging skills │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │   PHASE 0                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  🔒 CONTEXT LOCK                            │       │
    │   │  Embed: memory rules, brand, patterns       │       │
    │   │  (Builder will NEVER reload these)          │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │   PHASE 1                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  ❓ REQUIREMENTS GATHERING                  │       │
    │   │  Load team members, ask questions           │       │
    │   │  One topic at a time, wait for answers      │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │   PHASE 2                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  🏗️ PLAN CONSTRUCTION                       │       │
    │   │  Create atomic steps with:                  │       │
    │   │  • Micro-actions (exact tool calls)         │       │
    │   │  • Validation commands (executable)         │       │
    │   │  • Retry behavior (pre-defined)             │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │   PHASE 3                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  ⚔️ CHALLENGE PHASE                         │       │
    │   │  Run the Five Challenges:                   │       │
    │   │  1. Requirements - Does it solve the ask?   │       │
    │   │  2. Edge Cases - What could break?          │       │
    │   │  3. Simplicity - Is it minimal?             │       │
    │   │  4. Integration - Does it fit?              │       │
    │   │  5. Failure Modes - What if it fails?       │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │   PHASE 4                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  📊 CONFIDENCE SCORING                      │       │
    │   │  Score across 4 dimensions (100 points):    │       │
    │   │  • Requirements (25)  • Context (25)        │       │
    │   │  • Step Quality (25)  • Risk (25)           │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │                            ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  📄 OUTPUT: plan.json                       │       │
    │   │  Ready for Builder execution                │       │
    │   └─────────────────────────────────────────────┘       │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

**Key Outputs:**
- `plan.json` - Complete execution plan with embedded context
- `manifest.json` - Initial state with status READY_TO_BUILD

### 🟡 The Builder

**Mission:** Execute the plan exactly as specified. No interpretation. No improvisation.

```
                           BUILDER WORKFLOW
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
    │   PHASE A                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  📥 PLAN LOAD                               │       │
    │   │  Read plan.json and embedded_context        │       │
    │   │  (All rules already embedded - no reload)   │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │   PHASE B                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  🔄 EXECUTION LOOP (for each step)          │       │
    │   │                                             │       │
    │   │  ┌─────────────────────────────────────┐    │       │
    │   │  │  1. Execute micro-actions            │    │       │
    │   │  │     (exact tool calls from plan)     │    │       │
    │   │  └─────────────────────────────────────┘    │       │
    │   │                    │                        │       │
    │   │                    ▼                        │       │
    │   │  ┌─────────────────────────────────────┐    │       │
    │   │  │  2. Run validation commands          │    │       │
    │   │  │     (shell-executable checks)        │    │       │
    │   │  └─────────────────────────────────────┘    │       │
    │   │                    │                        │       │
    │   │           ┌───────┴───────┐                 │       │
    │   │           ▼               ▼                 │       │
    │   │       ┌──────┐       ┌──────────┐           │       │
    │   │       │ PASS │       │   FAIL   │           │       │
    │   │       └──┬───┘       └────┬─────┘           │       │
    │   │          │                │                 │       │
    │   │          ▼                ▼                 │       │
    │   │    Continue to      Apply fix_hints        │       │
    │   │    next step        Retry (up to max)      │       │
    │   │                                             │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │   PHASE C                  ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  ✅ QUALITY GATE                            │       │
    │   │  Run all quality checks:                    │       │
    │   │  • npm test                                 │       │
    │   │  • npx tsc --noEmit                         │       │
    │   │  • npm run lint                             │       │
    │   │                                             │       │
    │   │  Verdict: STRONG | SOUND | BLOCKED          │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │                            ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  📄 OUTPUT: Updated manifest.json           │       │
    │   │  Status: COMPLETE (if quality gate passed)  │       │
    │   └─────────────────────────────────────────────┘       │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

**Core Principles:**
1. **Trust the Plan** - Planner already made all decisions
2. **No Interpretation** - Execute exact micro-actions
3. **Validation is Mandatory** - Never skip checks
4. **Retry, Don't Replan** - Use embedded fix_hints

### 🟣 The Content Writer

**Mission:** Create strategic, brand-aligned content that converts.

```
                       CONTENT WRITER WORKFLOW
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  🎨 BRAND LOAD                              │       │
    │   │  Load: identity, voice, audiences, messaging│       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │                            ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  🔍 STRATEGIC DIAGNOSIS                     │       │
    │   │  • Topic analysis                           │       │
    │   │  • Audience fit                             │       │
    │   │  • Competitive angle                        │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │                            ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  📐 CONTENT ARCHITECTURE                    │       │
    │   │  Problem-first framework:                   │       │
    │   │  1. Hook (pain point)                       │       │
    │   │  2. Agitate (consequences)                  │       │
    │   │  3. Solution (your approach)                │       │
    │   │  4. Proof (evidence)                        │       │
    │   │  5. CTA (next step)                         │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │                            ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  ✍️ DRAFTING                                │       │
    │   │  Apply voice rules:                         │       │
    │   │  • Personality traits                       │       │
    │   │  • Vocabulary preferences                   │       │
    │   │  • Writing principles                       │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │                            ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  🚀 OPTIMIZATION                            │       │
    │   │  • SEO (keywords, meta)                     │       │
    │   │  • Formatting (headings, lists)             │       │
    │   │  • Conversion (CTAs, links)                 │       │
    │   └─────────────────────────────────────────────┘       │
    │                            │                            │
    │                            ▼                            │
    │   ┌─────────────────────────────────────────────┐       │
    │   │  📄 OUTPUT: Brand-aligned MDX content       │       │
    │   └─────────────────────────────────────────────┘       │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

---

## Commands Reference

### Build Commands

| Command | Description |
|---------|-------------|
| `/build <goal>` | Start a new build |
| `/build:preview <goal>` | Preview what would happen (dry-run) |
| `/build:interactive <goal>` | Step-by-step with confirmation |
| `/build:resume [task_id]` | Resume a paused build |
| `/build:status [task_id]` | Check build status |
| `/build:abort [task_id]` | Cancel a build |
| `/build:list` | List all builds |

### Brand Commands

| Command | Description |
|---------|-------------|
| `/brand` | Start brand discovery (5 phases) |
| `/brand:update [area]` | Update specific area |
| `/brand:audit` | Check brand consistency |
| `/brand:export [format]` | Export brand guide |

### Content Commands

| Command | Description |
|---------|-------------|
| `/blog "topic"` | Create full blog post |
| `/blog:outline "topic"` | Create outline only |
| `/blog:audit "url"` | Audit existing content |
| `/blog:series "theme"` | Plan content series |
| `/blog:ideas` | Generate topic ideas |

### Project Commands

| Command | Description |
|---------|-------------|
| `/project:init <name>` | Create new project |
| `/project:task <goal>` | Add task with dependencies |
| `/project:status` | Show project status |
| `/project:graph` | Display dependency graph |
| `/project:run` | Calculate execution order |

### Utility Commands

| Command | Description |
|---------|-------------|
| `/analytics` | View build analytics dashboard |
| `/trace [task_id]` | Show requirements traceability |
| `/rollback:list` | List rollback points |
| `/rollback:to <task_id>` | Rollback to pre-task state |

---

## The Hook System

STUDIO uses hooks to intercept lifecycle events and add intelligence:

```
                            HOOK LIFECYCLE
                                  │
    ┌─────────────────────────────┼─────────────────────────────┐
    │                             │                             │
    │   ┌─────────────────────────▼─────────────────────────┐   │
    │   │                   SessionStart                    │   │
    │   │   • Initialize context                            │   │
    │   │   • Check for incomplete tasks                    │   │
    │   │   • Prompt for resume if found                    │   │
    │   └───────────────────────────────────────────────────┘   │
    │                             │                             │
    │                             ▼                             │
    │   ┌─────────────────────────────────────────────────────┐ │
    │   │                  UserPromptSubmit                   │ │
    │   │   • Inject context before processing                │ │
    │   └─────────────────────────────────────────────────────┘ │
    │                             │                             │
    │                             ▼                             │
    │   ┌─────────────────────────────────────────────────────┐ │
    │   │                   SubagentStart                     │ │
    │   │   • Pre-flight checks for builder                   │ │
    │   │   • Verify plan exists and is approved              │ │
    │   └─────────────────────────────────────────────────────┘ │
    │                             │                             │
    │                             ▼                             │
    │   ┌─────────────────────────────────────────────────────┐ │
    │   │                    PreToolUse                       │ │
    │   │   • Plan alignment check                            │ │
    │   │   • Interactive mode confirmation                   │ │
    │   └─────────────────────────────────────────────────────┘ │
    │                             │                             │
    │                      ┌──────┴──────┐                      │
    │                      ▼             ▼                      │
    │   ┌──────────────────────┐ ┌──────────────────────────┐   │
    │   │    PostToolUse       │ │  PostToolUseFailure      │   │
    │   │  • Track progress    │ │  • Classify error        │   │
    │   │  • Emit progress bar │ │  • Suggest fixes         │   │
    │   │  • Detect corrections│ │  • Offer auto-fix        │   │
    │   └──────────────────────┘ └──────────────────────────┘   │
    │                             │                             │
    │                             ▼                             │
    │   ┌─────────────────────────────────────────────────────┐ │
    │   │                   SubagentStop                      │ │
    │   │   • Planner: Validate plan, calculate confidence    │ │
    │   │   • Builder: Self-review, check requirements        │ │
    │   └─────────────────────────────────────────────────────┘ │
    │                             │                             │
    │                             ▼                             │
    │   ┌─────────────────────────────────────────────────────┐ │
    │   │                       Stop                          │ │
    │   │   • Quality gate validation                         │ │
    │   │   • Final checks before completion                  │ │
    │   └─────────────────────────────────────────────────────┘ │
    │                                                           │
    └───────────────────────────────────────────────────────────┘
```

### Hook Types

| Type | Description | Use Case |
|------|-------------|----------|
| `command` | Run shell script | Progress tracking, error classification |
| `prompt` | Quick LLM check | Plan alignment, validation |
| `agent` | Full agent call | Self-review, complex analysis |

---

## Playbooks & Methodologies

Playbooks teach agents **how to think**. They're loaded before work begins.

```
                         PLAYBOOK SYSTEM
    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │   📚 CORE METHODOLOGIES                                 │
    │   ┌─────────────────────────────────────────────────┐   │
    │   │  planning/     How to create execution plans    │   │
    │   │  building/     How to execute plans             │   │
    │   │  validation/   Adversarial review + scoring     │   │
    │   │  reviewing/    How to verify and reflect        │   │
    │   └─────────────────────────────────────────────────┘   │
    │                                                         │
    │   🧠 LEARNING & QUALITY                                 │
    │   ┌─────────────────────────────────────────────────┐   │
    │   │  memory/       How to learn and remember        │   │
    │   │  orchestration/ Multi-agent coordination        │   │
    │   │  context-management/ Context optimization       │   │
    │   └─────────────────────────────────────────────────┘   │
    │                                                         │
    │   🎨 BRAND & CONTENT                                    │
    │   ┌─────────────────────────────────────────────────┐   │
    │   │  brand/        How to discover brand identity   │   │
    │   │  content/      How to create aligned content    │   │
    │   └─────────────────────────────────────────────────┘   │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

### The Five Challenges (from `validation/SKILL.md`)

Before any plan is executed, it must pass:

```
╔═══════════════════════════════════════════════════════════════════════╗
║                        THE FIVE CHALLENGES                            ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║   1️⃣  REQUIREMENTS                                                    ║
║       "Does this plan actually solve what was asked?"                 ║
║       • Check scope coverage                                          ║
║       • Verify success criteria alignment                             ║
║                                                                       ║
║   2️⃣  EDGE CASES                                                      ║
║       "What inputs or conditions would break this?"                   ║
║       • Null/empty inputs                                             ║
║       • Boundary conditions                                           ║
║       • Concurrent access                                             ║
║                                                                       ║
║   3️⃣  SIMPLICITY                                                      ║
║       "Is this the simplest possible solution?"                       ║
║       • Remove unnecessary steps                                      ║
║       • Avoid over-engineering                                        ║
║       • Question every abstraction                                    ║
║                                                                       ║
║   4️⃣  INTEGRATION                                                     ║
║       "Does this fit with the existing codebase?"                     ║
║       • Follow existing patterns                                      ║
║       • Respect naming conventions                                    ║
║       • Use established libraries                                     ║
║                                                                       ║
║   5️⃣  FAILURE MODES                                                   ║
║       "When this fails, what happens?"                                ║
║       • Error handling                                                ║
║       • Recovery paths                                                ║
║       • User feedback                                                 ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## The Team System

STUDIO uses domain expert personas to ensure thorough requirements gathering:

```
                            TEAM STRUCTURE
    ┌─────────────────────────────────────────────────────────────────┐
    │                                                                 │
    │   TIER 1: CORE SPECIALISTS (Always Loaded)                      │
    │   ┌───────────────────────────────────────────────────────────┐ │
    │   │                                                           │ │
    │   │  👔 Orchestrator        Scope, priorities, success        │ │
    │   │  📋 Business Analyst    Requirements, processes, rules    │ │
    │   │  🏗️ Tech Lead           Architecture, patterns, scale     │ │
    │   │  💻 Frontend Spec       Components, state, UX             │ │
    │   │  🖥️ Backend Spec        APIs, data, integrations          │ │
    │   │  🎨 UI/UX Designer      Flows, design, accessibility      │ │
    │   │  🎯 Brand Strategist    Identity, voice, positioning      │ │
    │   │                                                           │ │
    │   └───────────────────────────────────────────────────────────┘ │
    │                                                                 │
    │   TIER 2: QUALITY SPECIALISTS (Loaded for Quality Tasks)        │
    │   ┌───────────────────────────────────────────────────────────┐ │
    │   │                                                           │ │
    │   │  🧪 QA Refiner          Testing, edge cases, coverage     │ │
    │   │  🔒 Security Analyst    Auth, data protection, compliance │ │
    │   │  🚀 DevOps Engineer     Deployment, monitoring, infra     │ │
    │   │                                                           │ │
    │   └───────────────────────────────────────────────────────────┘ │
    │                                                                 │
    │   TIER 3: GROWTH SPECIALISTS (Loaded for User-Facing Tasks)     │
    │   ┌───────────────────────────────────────────────────────────┐ │
    │   │                                                           │ │
    │   │  ✍️ Content Strategist  Copy, messaging, microcopy        │ │
    │   │  ⚖️ Legal Compliance    Regulations, terms, privacy       │ │
    │   │  📈 SEO & Growth        Search, discoverability           │ │
    │   │                                                           │ │
    │   └───────────────────────────────────────────────────────────┘ │
    │                                                                 │
    └─────────────────────────────────────────────────────────────────┘
```

### How Team Members Work

Each team member provides **specific questions** to ask during requirements:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     BUSINESS ANALYST QUESTIONS                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  📍 USER JOURNEY                                                    │
│  "Walk me through the complete user journey for this feature"       │
│                                                                     │
│  📊 DATA REQUIREMENTS                                               │
│  "What data needs to be captured, stored, or retrieved?"            │
│                                                                     │
│  📏 BUSINESS RULES                                                  │
│  "What validation rules or business logic must be enforced?"        │
│                                                                     │
│  🔄 STATE & LIFECYCLE                                               │
│  "What states can this entity be in? What triggers transitions?"    │
│                                                                     │
│  ⚠️ ERROR HANDLING                                                  │
│  "What should happen when things go wrong?"                         │
│                                                                     │
│  📤 OUTPUTS                                                         │
│  "What reports, exports, or integrations are needed?"               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Memory System

STUDIO learns from your preferences and remembers them:

```
                          MEMORY SYSTEM
    ┌─────────────────────────────────────────────────────────────────┐
    │                                                                 │
    │   📂 studio/rules/                                              │
    │   ├── global.md         Project-wide conventions                │
    │   ├── frontend.md       UI/UX preferences                       │
    │   ├── backend.md        API/architecture patterns               │
    │   ├── testing.md        Testing requirements                    │
    │   ├── security.md       Security constraints                    │
    │   └── devops.md         Infrastructure preferences              │
    │                                                                 │
    │   ┌─────────────────────────────────────────────────────────┐   │
    │   │                  HOW LEARNING WORKS                     │   │
    │   │                                                         │   │
    │   │   User corrects something                               │   │
    │   │            │                                            │   │
    │   │            ▼                                            │   │
    │   │   STUDIO detects correction                             │   │
    │   │            │                                            │   │
    │   │            ▼                                            │   │
    │   │   "Should I remember this preference?"                  │   │
    │   │            │                                            │   │
    │   │     ┌──────┴──────┐                                     │   │
    │   │     ▼             ▼                                     │   │
    │   │   [Yes]         [No]                                    │   │
    │   │     │                                                   │   │
    │   │     ▼                                                   │   │
    │   │   Write to appropriate rules file                       │   │
    │   │     │                                                   │   │
    │   │     ▼                                                   │   │
    │   │   Future builds use this rule                           │   │
    │   │                                                         │   │
    │   └─────────────────────────────────────────────────────────┘   │
    │                                                                 │
    └─────────────────────────────────────────────────────────────────┘
```

### Example Memory Rules

```markdown
# studio/rules/global.md

## Coding Standards
- Use TypeScript strict mode for all new files
- Prefer functional components over class components
- Use named exports instead of default exports

## Formatting
- Use 2-space indentation
- Maximum line length: 100 characters
- Use single quotes for strings

## Dependencies
- Prefer Zod over Yup for validation
- Use date-fns instead of moment.js
```

---

## Quality Assurance

### Confidence Scoring

Before execution, every plan gets a confidence score:

```
╔══════════════════════════════════════════════════════════════╗
║  PLAN CONFIDENCE: 85%                                        ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Requirements:    [████████░░] 80%                           ║
║    ✓ All personas consulted                                  ║
║    ✓ User confirmed requirements                             ║
║    ⚠ 1 edge case not addressed                               ║
║                                                              ║
║  Step Quality:    [██████████] 100%                          ║
║    ✓ All steps atomic                                        ║
║    ✓ All have validation commands                            ║
║    ✓ Dependencies clear                                      ║
║                                                              ║
║  Context:         [████████░░] 80%                           ║
║    ✓ 5 Memory rules embedded                                 ║
║    ✓ 3 patterns discovered                                   ║
║    ⚠ No constraints documented                               ║
║                                                              ║
║  Risk:            [████████░░] 80%                           ║
║    ✓ Failure modes identified                                ║
║    ✓ Retry behavior defined                                  ║
║    ✓ Rollback possible                                       ║
║                                                              ║
║  Recommendation: PROCEED_WITH_CAUTION                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

### Quality Gate Verdicts

| Verdict | Meaning | Action |
|---------|---------|--------|
| **STRONG** | All checks pass | Build complete |
| **SOUND** | Required pass, optional warnings | Build complete with notes |
| **BLOCKED** | Required check failed | Fix required before completion |

### Requirements Traceability

Every requirement maps to implementation and verification:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  REQUIREMENTS TRACEABILITY                                                     ║
╠═══════════╦═══════════════════════════════╦═══════════════╦════════════════════╣
║ REQ ID    ║ Description                   ║ Steps         ║ Verification       ║
╠═══════════╬═══════════════════════════════╬═══════════════╬════════════════════╣
║ REQ-001   ║ User registration             ║ STEP-1,2      ║ auth.test.ts:12    ║
║ REQ-002   ║ Password validation           ║ STEP-1        ║ auth.test.ts:24    ║
║ REQ-003   ║ Email uniqueness              ║ STEP-3        ║ auth.test.ts:36    ║
╚═══════════╩═══════════════════════════════╩═══════════════╩════════════════════╝

Coverage: 3/3 requirements implemented and verified (100%)
```

---

## Advanced Features

### Parallel Execution

Steps without dependencies can run simultaneously:

```
                    PARALLEL EXECUTION
    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │   Batch 1: [step_1]              Sequential             │
    │                │                                        │
    │                ▼                                        │
    │   Batch 2: [step_2, step_3]      ◀─── PARALLEL          │
    │              │     │                                    │
    │              └──┬──┘                                    │
    │                 ▼                                       │
    │   Batch 3: [step_4]              Sequential             │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

### Project Orchestration

Manage multiple related tasks with dependencies:

```
                    PROJECT GRAPH
    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │   [Auth] ────────┐                                      │
    │                  ├───▶ [Cart] ───▶ [Checkout]           │
    │   [Catalog] ─────┘                                      │
    │                                                         │
    │   Execution Order:                                      │
    │   1. Auth + Catalog (parallel - no dependencies)        │
    │   2. Cart (waits for Auth + Catalog)                    │
    │   3. Checkout (waits for Cart)                          │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

### Rollback System

Git-based snapshots for task-level recovery:

```bash
# List available rollback points
/rollback:list

╔══════════════════════════════════════════════════════════════╗
║  ROLLBACK POINTS                                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  task_20260201_150000                                        ║
║  ├─ Date:   2026-02-01                                       ║
║  ├─ Commit: a1b2c3d4                                         ║
║  └─ Since:  5 files changed, 150 insertions(+)               ║
║                                                              ║
║  task_20260201_120000                                        ║
║  ├─ Date:   2026-02-01                                       ║
║  ├─ Commit: e5f6g7h8                                         ║
║  └─ Since:  12 files changed, 400 insertions(+)              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

# Preview what would revert
/rollback:preview task_20260201_150000

# Execute rollback
/rollback:to task_20260201_150000 --force
```

### Analytics Dashboard

Track your build metrics:

```
╔══════════════════════════════════════════════════════════════╗
║  STUDIO ANALYTICS (Last 30 days)                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Build Summary                                               ║
║  ├─ Total:      24 builds                                    ║
║  ├─ Complete:   20                                           ║
║  ├─ Failed:     2                                            ║
║  ├─ Halted:     1                                            ║
║  └─ Aborted:    1                                            ║
║                                                              ║
║  Success Rate                                                ║
║  [████████████████░░░░] 83%                                  ║
║                                                              ║
║  Averages                                                    ║
║  ├─ Duration:  45s per build                                 ║
║  ├─ Steps:     6.2 per build                                 ║
║  └─ Retries:   0.8 per build                                 ║
║                                                              ║
║  Quality Verdicts                                            ║
║  ├─ STRONG:   15                                             ║
║  ├─ SOUND:    5                                              ║
║  ├─ UNSTABLE: 2                                              ║
║  └─ BLOCKED:  2                                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

---

## File Reference

### Key Files Quick Reference

| File | Purpose |
|------|---------|
| `agents/planner.yaml` | Planner agent configuration |
| `agents/builder.yaml` | Builder agent configuration |
| `hooks/hooks.json` | Lifecycle hooks (v5.0.0) |
| `playbooks/*/SKILL.md` | Methodology definitions |
| `team/tier*/` | Domain expert personas |
| `schemas/*.json` | Validation schemas |
| `scripts/output.sh` | Terminal formatting |
| `scripts/backlog.sh` | Backlog management |
| `scripts/learnings.sh` | Learning capture & classification |
| `scripts/signal-audit.sh` | Signal vs. noise filtering |
| `scripts/sprint-evolution.sh` | Post-sprint self-correction |
| `scripts/orchestrator.sh` | Multi-agent orchestration |
| `scripts/context-manager.sh` | Context optimization |
| `STUDIO_KNOWLEDGE_BASE.md` | Active architectural constraints |
| `studio/prompts/self-learning.md` | Self-learning protocol |
| `studio/config/tracked-frameworks.json` | Framework signal detection |

### Generated Files

| File | Created By | Purpose |
|------|------------|---------|
| `studio/projects/*/project.json` | `/project:init` | Project manifest |
| `studio/projects/*/tasks/*/plan.json` | Planner | Execution plan |
| `studio/projects/*/tasks/*/manifest.json` | Builder | Task state |
| `studio/rules/*.md` | Memory system | Learned rules |
| `studio/learnings/*.md` | Builder (learn phase) | Domain learnings |
| `studio/data/analytics.json` | Analytics | Build metrics |
| `brand/*.yaml` | `/brand` | Brand identity |
| `.studio/sprint-counter.json` | Sprint evolution | Sprint tracking state |

---

## Knowledge Evolution System

STUDIO actively evolves its architectural understanding through the Dynamic SOP System.

### Knowledge Base Structure

The `STUDIO_KNOWLEDGE_BASE.md` file at the project root contains verified patterns:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       STUDIO KNOWLEDGE BASE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  STRICT CONSTRAINTS                                              │   │
│  │  Rules that kill performance, quality, or maintainability        │   │
│  │                                                                  │   │
│  │  Promotion: 2+ occurrences across different tasks               │   │
│  │  Injection: Loaded into agent context as "NEVER VIOLATE" list   │   │
│  │                                                                  │   │
│  │  Example:                                                        │   │
│  │  ### SC-001: Never mutate state directly in React               │   │
│  │  **What**: Never use array.push() or object mutation in state   │   │
│  │  **Instead**: Use spread operator or immer                       │   │
│  │  **Source**: task_20240215_auth, task_20240218_cart             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  SLOP LEDGER                                                     │   │
│  │  Naming conventions, structural mistakes that cause rework       │   │
│  │                                                                  │   │
│  │  Promotion: 1 occurrence + documented rework impact             │   │
│  │  Injection: Loaded as "AVOID THESE MISTAKES" per domain         │   │
│  │                                                                  │   │
│  │  Example:                                                        │   │
│  │  ### SL-001: Inconsistent file naming                           │   │
│  │  **Pattern**: Mixed camelCase and kebab-case in components      │   │
│  │  **Fix**: Use kebab-case for files, PascalCase for components   │   │
│  │  **Rework Cost**: 30 minutes renaming and updating imports      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  PERFORMANCE DELTA                                               │   │
│  │  Measured before/after improvements with concrete numbers        │   │
│  │                                                                  │   │
│  │  Requirement: Must have quantified metrics                       │   │
│  │                                                                  │   │
│  │  Example:                                                        │   │
│  │  ### PD-001: Lazy loading images                                │   │
│  │  **Metric**: Largest Contentful Paint (LCP)                     │   │
│  │  **Before**: 2.4s                                               │   │
│  │  **After**: 1.1s                                                │   │
│  │  **Delta**: 54% improvement                                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  PENDING QUEUE                                                   │   │
│  │  Signals awaiting promotion when thresholds are met              │   │
│  │                                                                  │   │
│  │  Items with 1 occurrence wait here                               │   │
│  │  On 2nd occurrence → Promote to Strict Constraints              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Signal vs. Noise Filtering

The `scripts/signal-audit.sh` script automatically classifies learnings:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SIGNAL CLASSIFICATION FLOW                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  INPUT: "Fixed memory leak - heap reduced from 512MB to 128MB"         │
│                         │                                               │
│                         ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  NOISE CHECK                                                     │   │
│  │  ✗ No task_id? → FILTER OUT                                     │   │
│  │  ✗ Contains "how to", "basic", "simple"? → FILTER OUT           │   │
│  │  ✗ No measurable impact? → FILTER OUT                           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                         │ (passes)                                      │
│                         ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  SIGNAL TYPE DETECTION                                           │   │
│  │                                                                  │   │
│  │  Keywords: "memory", "512MB", "128MB" → PERFORMANCE              │   │
│  │  Keywords: "error", "crash", "fix" → ERROR                       │   │
│  │  Keywords: "naming", "structure" → CONVENTION                    │   │
│  │  Framework match → FRAMEWORK                                     │   │
│  │  Default → PATTERN                                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                         │                                               │
│                         ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  DESTINATION ROUTING                                             │   │
│  │                                                                  │   │
│  │  PERFORMANCE → Performance Delta (must have numbers)             │   │
│  │  ERROR (1st) → Pending Queue                                     │   │
│  │  ERROR (2nd) → Strict Constraints                                │   │
│  │  CONVENTION → Slop Ledger                                        │   │
│  │  FRAMEWORK → Pending Queue                                       │   │
│  │  PATTERN → Domain learnings (studio/learnings/{domain}.md)      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  OUTPUT: {"signal_type": "performance", "destination": "perf_delta"}   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Sprint Evolution Protocol

Every 5 tasks, the `scripts/sprint-evolution.sh` triggers evolution proposals:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SPRINT EVOLUTION PROTOCOL                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  TRIGGER: Task count reaches 5 (configurable)                           │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  PROPOSAL TYPE 1: DELETABLE RULES                                │   │
│  │                                                                  │   │
│  │  Scan Strict Constraints for rules with:                         │   │
│  │  • No violations in 10+ tasks                                    │   │
│  │  • May be obsolete or overly specific                           │   │
│  │                                                                  │   │
│  │  Proposal: "Consider removing SC-003 - no violations in 15 tasks"│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  PROPOSAL TYPE 2: NEW ENFORCEMENT RULES                          │   │
│  │                                                                  │   │
│  │  Scan recent learnings for:                                      │   │
│  │  • High-impact patterns (crash, fail, broke)                     │   │
│  │  • Items in Pending Queue with 2+ occurrences                    │   │
│  │                                                                  │   │
│  │  Proposal: "Promote 'Always validate OAuth tokens' to Strict"    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  USER REVIEW                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Accept / Reject each proposal                                   │   │
│  │  Approved changes applied to STUDIO_KNOWLEDGE_BASE.md            │   │
│  │  Sprint counter resets for next evolution cycle                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Self-Learning Protocol

After every build, the Builder agent captures learnings using `studio/prompts/self-learning.md`:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     DEFINITION OF DONE (Learning)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  A task is NOT complete until:                                          │
│                                                                         │
│  [ ] Learning extracted and classified                                  │
│      • task_id generated                                                │
│      • domain detected (frontend/backend/testing/etc.)                  │
│      • impact_type assigned (constraint/slop/performance/pattern)       │
│      • severity rated (HIGH/MEDIUM/LOW)                                 │
│      • measurable_outcome captured (if applicable)                      │
│                                                                         │
│  [ ] Knowledge base checked for duplicates                              │
│      • Run: ./scripts/learnings.sh check-duplicate "title"              │
│                                                                         │
│  [ ] Sprint counter incremented                                         │
│      • Run: ./scripts/sprint-evolution.sh increment <task_id>           │
│      • If output is "EVOLUTION_DUE", notify user                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Learning Commands

```bash
# Classify a learning entry
./scripts/learnings.sh classify "Fixed memory leak in task_xxx - reduced heap from 512MB to 128MB"
# Output: {"signal_type": "performance", "destination": "performance_delta", ...}

# Check for duplicates
./scripts/learnings.sh check-duplicate "Memory Optimization Pattern"

# Extract metrics from text
./scripts/learnings.sh extract-metrics "LCP improved from 2.4s to 1.1s"

# Signal audit
./scripts/signal-audit.sh classify "text"
./scripts/signal-audit.sh is-noise "text"
./scripts/signal-audit.sh detect-type "text"

# Sprint evolution
./scripts/sprint-evolution.sh status      # Show sprint progress
./scripts/sprint-evolution.sh propose     # Generate evolution proposals
./scripts/sprint-evolution.sh reset       # Start new sprint after review
```

### Framework Tracking

The `studio/config/tracked-frameworks.json` file configures signal detection:

```json
{
  "frameworks": [
    {"name": "next.js", "keywords": ["next", "app router", "server component"]},
    {"name": "react", "keywords": ["useState", "useEffect", "component"]},
    {"name": "prisma", "keywords": ["prisma", "orm", "migration"]}
  ],
  "custom_signals": [
    {"pattern": "hydration", "destination": "frontend", "severity": "HIGH"},
    {"pattern": "n+1", "destination": "backend", "severity": "HIGH"}
  ]
}
```

---

## Summary

STUDIO transforms AI-assisted development through:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   🎯 GOAL-ORIENTED                                                      │
│      Start with what you want to achieve, not how                       │
│                                                                         │
│   🧠 INTELLIGENT PLANNING                                               │
│      Domain experts ensure thorough requirements                        │
│                                                                         │
│   ⚔️ ADVERSARIAL REVIEW                                                 │
│      Every plan challenged before execution                             │
│                                                                         │
│   ✅ VERIFIED EXECUTION                                                 │
│      Every step validated with executable checks                        │
│                                                                         │
│   📚 CONTINUOUS LEARNING                                                │
│      Preferences remembered across sessions                             │
│                                                                         │
│   🎨 BRAND CONSISTENCY                                                  │
│      All content aligned with your voice                                │
│                                                                         │
│   ↩️ RECOVERABLE                                                        │
│      Rollback to any point if needed                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

*Built with precision. Executed with confidence. Learned continuously.*

**Version:** 5.0.0 | **License:** MIT
