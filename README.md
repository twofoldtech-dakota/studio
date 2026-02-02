# STUDIO

> **S**elf-**T**eaching **U**nified **D**evelopment & **I**ntelligent **O**rchestration

**AI builds code. STUDIO makes sure it's correct.**

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   🎯 GOAL              📋 PLAN                🔨 BUILD            ✅ VERIFIED  ║
║                                                                               ║
║   "Add user     ───▶   Atomic steps   ───▶   Execute &    ───▶   Quality      ║
║    auth"               with validation       validate            gate passed  ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## Why STUDIO?

| AI Problem | STUDIO Solution |
|------------|-----------------|
| 🤔 Assumes requirements | Mandatory questioning with domain experts |
| 🏃 Declares success early | Quality gates block incomplete work |
| 🌊 Drifts from intent | Plan anchors every execution step |
| 🧠 Forgets your preferences | Memory system persists rules across sessions |
| 🎭 Inconsistent voice | Brand context embedded in every plan |
| ❌ Silent failures | Classified errors with fix suggestions |
| 😰 No recovery option | Git-based rollback to any task |

---

## Quick Start

### Installation

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Start Claude Code
claude

# Add STUDIO plugin
/plugin marketplace add https://github.com/twofoldtech-dakota/studio.git
/plugin install studio@studio-marketplace
```

### Your First Build

```bash
/build "Add user authentication with email verification"
```

STUDIO will:
1. **Ask clarifying questions** using domain expert personas
2. **Create an execution-ready plan** with atomic, validated steps
3. **Challenge the plan** for edge cases and risks
4. **Execute with validation** and automatic retry on failure
5. **Run quality gates** before marking complete

### Your First Brand Setup

```bash
/brand
```

Complete a 5-phase guided interview to establish:
- **Identity** — Mission, vision, values, personality
- **Audience** — Who you serve, their pain points
- **Voice** — How you sound, vocabulary, principles
- **Positioning** — Market category, differentiation
- **Messaging** — Value propositions, key messages

---

## Commands

### Build Commands

| Command | Description |
|---------|-------------|
| `/build "goal"` | Start a new build |
| `/build:preview "goal"` | Preview what would happen (dry-run) |
| `/build:interactive "goal"` | Step-by-step with confirmation |
| `/build resume` | Resume incomplete build |
| `/build status` | Check current build |
| `/build abort` | Cancel build |

### Brand & Content

| Command | Description |
|---------|-------------|
| `/brand` | Start brand discovery |
| `/brand:update [area]` | Update identity, voice, audience, or messaging |
| `/brand:audit` | Check brand consistency |
| `/blog "topic"` | Create brand-aligned blog post |
| `/blog:outline "topic"` | Create outline only |
| `/blog:ideas` | Generate topic ideas |

### Project Management

| Command | Description |
|---------|-------------|
| `/project:init "name"` | Create multi-task project |
| `/project:task "goal"` | Add task with dependencies |
| `/project:status` | Show project status |
| `/project:graph` | Display dependency graph |

### Utilities

| Command | Description |
|---------|-------------|
| `/analytics` | View build metrics dashboard |
| `/trace` | Show requirements traceability |
| `/rollback:list` | List recovery points |
| `/rollback:to <task>` | Rollback to pre-task state |

---

## The Three Agents

```
┌─────────────────────┬─────────────────────┬─────────────────────────────┐
│                     │                     │                             │
│   🔵 THE PLANNER    │   🟡 THE BUILDER     │   🟣 THE CONTENT WRITER     │
│                     │                     │                             │
│   Creates plans     │   Executes plans    │   Creates content           │
│   Embeds context    │   Validates steps   │   Applies brand voice       │
│   Challenges self   │   Retries on fail   │   Optimizes for SEO         │
│                     │                     │                             │
└─────────────────────┴─────────────────────┴─────────────────────────────┘
```

### The Planner
- Loads **playbooks** (methodologies for thinking)
- Consults **team members** (domain expert personas)
- Embeds **memory rules** (your preferences)
- Runs **Five Challenges** (adversarial self-review)
- Calculates **confidence score** before execution

### The Builder
- Executes **exactly** what the plan specifies
- Runs **validation commands** after each step
- Applies **fix hints** and retries on failure
- Triggers **quality gate** before completion
- **Never improvises** — follows the plan

### The Content Writer
- Loads **brand context** (identity, voice, audiences)
- Applies **voice rules** consistently
- Structures with **problem-first framework**
- Optimizes for **SEO** and conversion
- Verifies **brand alignment**

---

## Quality Assurance

### Confidence Scoring

Every plan gets scored before execution:

```
╔══════════════════════════════════════════════════════════════╗
║  PLAN CONFIDENCE: 85% (MEDIUM)                               ║
╠══════════════════════════════════════════════════════════════╣
║  Requirements:    [████████░░] 80%                           ║
║  Step Quality:    [██████████] 100%                          ║
║  Context:         [████████░░] 80%                           ║
║  Risk:            [████████░░] 80%                           ║
╚══════════════════════════════════════════════════════════════╝
```

### The Five Challenges

Before any plan executes, it must answer:

1. **REQUIREMENTS** — Does this solve what was asked?
2. **EDGE CASES** — What inputs would break this?
3. **SIMPLICITY** — Is this the simplest solution?
4. **INTEGRATION** — Does this fit the codebase?
5. **FAILURE MODES** — What happens when it fails?

### Quality Gate Verdicts

| Verdict | Meaning |
|---------|---------|
| **STRONG** | All checks passed |
| **SOUND** | Required passed, optional warnings |
| **BLOCKED** | Required check failed — fix required |

---

## Knowledge System

STUDIO actively learns and evolves its architectural understanding:

### Knowledge Base (`STUDIO_KNOWLEDGE_BASE.md`)

```
┌──────────────────────────────────────────────────────────────────────┐
│                     STUDIO KNOWLEDGE BASE                             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  STRICT CONSTRAINTS        Rules that kill performance/quality       │
│  (Never Violate)           Promoted after 2+ occurrences             │
│                                                                      │
│  SLOP LEDGER               Naming, structural mistakes               │
│                            Captured on 1st occurrence + rework       │
│                                                                      │
│  PERFORMANCE DELTA         Measured before/after metrics             │
│                            Must have concrete numbers                │
│                                                                      │
│  PENDING QUEUE             Signals awaiting promotion                │
│                            Moves to sections when thresholds met     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Sprint Evolution

Every 5 tasks, STUDIO proposes knowledge base evolution:
- **Deletable Rules**: Constraints with no violations in 10+ tasks
- **New Enforcement**: Highest-impact recurring patterns

### Signal vs. Noise Filtering

Learnings are automatically classified:
- **Performance** → Performance Delta (requires metrics)
- **Errors** → Pending Queue → Strict Constraints (after 2+)
- **Convention issues** → Slop Ledger
- **Patterns** → Domain learnings

### Memory Rules

```
studio/rules/
├── global.md       # Project-wide conventions
├── frontend.md     # UI/UX preferences
├── backend.md      # API/architecture patterns
├── testing.md      # Testing requirements
├── security.md     # Security constraints
└── devops.md       # Infrastructure preferences
```

When you correct something, STUDIO asks:
> "Should I remember this preference?"

If yes, it writes the rule and applies it to all future builds.

---

## Project Structure

```
studio/
├── 🤖 agents/              # Agent definitions (Planner, Builder, Content Writer)
├── 📋 commands/            # Available commands (/build, /brand, /blog, etc.)
├── 📚 playbooks/           # Methodologies (how agents think)
├── 👥 team/                # Domain expert personas (13 specialists)
├── 🔗 hooks/               # Lifecycle hooks (progress, errors, validation)
├── 📐 schemas/             # Validation schemas
├── 🎨 brand/               # Brand source of truth
├── 🔧 scripts/             # Runtime scripts
│   ├── learnings.sh        # Learning capture & classification
│   ├── signal-audit.sh     # Signal vs. noise filtering
│   ├── sprint-evolution.sh # Post-sprint self-correction
│   └── orchestrator.sh     # Multi-agent orchestration
├── 📊 data/                # Error patterns, analytics
├── 📝 templates/           # Code templates
├── 📖 docs/                # Documentation
│   ├── STUDIO-GUIDE.md     # Complete system guide
│   └── QUICK-REFERENCE.md  # Quick lookup card
└── 💾 studio/              # Runtime data
    ├── learnings/          # Domain-specific learnings
    ├── config/             # Framework tracking, signals
    └── prompts/            # System prompts (self-learning)

# Root level
├── STUDIO_KNOWLEDGE_BASE.md  # Active architectural constraints
└── .studio/                  # Session state
    └── sprint-counter.json   # Sprint evolution tracking
```

---

## Architecture

```
                              STUDIO SYSTEM
    ┌────────────────────────────────────────────────────────────────────┐
    │                                                                    │
    │   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌─────────┐   │
    │   │   USER   │────▶│ PLANNER  │────▶│ BUILDER  │────▶│ VERIFIED│   │
    │   │   GOAL   │     │  AGENT   │     │  AGENT   │     │  OUTPUT │   │
    │   └──────────┘     └────┬─────┘     └────┬─────┘     └────┬────┘   │
    │                         │                │                │        │
    │                    ┌────┴────────────────┴────┐           │        │
    │                    │                          │           │        │
    │              ┌─────┴─────┐            ┌───────┴───────┐   │        │
    │              │  MEMORY   │            │    HOOKS      │   │        │
    │              │  SYSTEM   │            │    SYSTEM     │   │        │
    │              │ (Learning)│            │ (Validation)  │   │        │
    │              └─────┬─────┘            └───────────────┘   │        │
    │                    │                                      │        │
    │              ┌─────┴─────────────────────────────────────┴──┐      │
    │              │              KNOWLEDGE BASE                   │      │
    │              │  ┌─────────┐ ┌─────────┐ ┌─────────────────┐ │      │
    │              │  │Strict   │ │  Slop   │ │  Performance    │ │      │
    │              │  │Constr.  │ │ Ledger  │ │     Delta       │ │      │
    │              │  └─────────┘ └─────────┘ └─────────────────┘ │      │
    │              └──────────────────────────────────────────────┘      │
    │                                                                    │
    └────────────────────────────────────────────────────────────────────┘
```

---

## Advanced Features

### Parallel Execution
Steps without dependencies run simultaneously for faster builds.

### Project Orchestration
Manage multiple related tasks with dependency graphs:
```
[Auth] ────┐
           ├───▶ [Cart] ───▶ [Checkout]
[Catalog] ─┘
```

### Rollback System
Git-based snapshots let you recover to any pre-task state:
```bash
/rollback:list              # See available points
/rollback:to <task> --force # Restore pre-task state
```

### Analytics Dashboard
Track build success rates, durations, and quality metrics:
```bash
/analytics                  # View dashboard
```

### Error Classification
20+ error patterns with contextual fix suggestions and auto-fix options.

### Interactive Mode
Step-by-step execution with confirmation at each change:
```bash
/build:interactive "goal"
```

### Optional MCP Integrations

Enhance STUDIO with additional AI capabilities:

**Context7** — Up-to-date documentation for any library:
```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
```

**Vercel MCP** — Manage Vercel projects and deployments:
```bash
claude mcp add --transport http vercel https://mcp.vercel.com
```

**Gemini Design MCP** — AI-powered design assistance:
```bash
claude mcp add gemini-design-mcp --env API_KEY=<your-api-key> -- npx -y gemini-design-mcp@latest
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [STUDIO-GUIDE.md](docs/STUDIO-GUIDE.md) | Complete system documentation with visuals |
| [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md) | Quick lookup card for commands |
| [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) | Feature implementation details |

---

## Stack

| Component | Technology |
|-----------|------------|
| Runtime | Claude Code Plugin |
| Agents | YAML definitions |
| Validation | JSON Schema |
| Hooks | Shell + LLM prompts |
| Storage | File-based (JSON, YAML, Markdown) |

---

## Philosophy

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   "Plan thoroughly, execute precisely, learn continuously"                    ║
║                                                                               ║
║   • Every plan is CHALLENGED before execution                                 ║
║   • Every step has EXECUTABLE validation                                      ║
║   • Every preference is REMEMBERED for future use                             ║
║   • Every requirement is TRACEABLE to implementation                          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## License

MIT

---

<p align="center">
  <b>Built with precision. Executed with confidence. Learned continuously.</b>
</p>
