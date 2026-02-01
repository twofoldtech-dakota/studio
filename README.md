# STUDIO

**AI builds code. STUDIO makes sure it's correct.**

---

## Architecture

```
GOAL ──→ PLAN ──→ BUILD ──→ VERIFIED
           │         │
           │         └── execute steps
           │             validate each
           │             retry on fail
           │
           └── gather requirements
               embed context
               embed brand (if user-facing)
               define validation
```

---

## Capabilities

### Code Workflows
- **Asks before assuming** — Probes scope, edge cases, success criteria
- **Plans before executing** — Atomic steps with validation commands
- **Verifies before completing** — Quality gates block incomplete work
- **Learns from corrections** — Memory persists per-project

### Brand & Content
- **Brand discovery** — Structured interviews establish voice and messaging
- **Content creation** — Brand-aligned blog posts and case studies
- **Voice consistency** — Embedded brand context ensures every piece sounds right

---

## Problem → Solution

| AI Failure | Fix |
|------------|-----|
| Assumes requirements | Mandatory interrogation phase |
| Declares success early | Quality gate blocks completion |
| Drifts from intent | Plan anchors execution |
| Forgets corrections | Memory persists rules |
| Inconsistent voice | Brand files embed in every plan |
| Generic content | Audience profiles drive relevance |

---

## Stack

| | |
|-|-|
| Runtime | Claude Code Plugin |
| Agents | YAML (Planner, Builder, Content Writer) |
| Validation | JSON Schema |
| Storage | File-based |

---

## Quick Start

```bash
npm install -g @anthropic-ai/claude-code
claude
/plugin marketplace add twofoldtech-dakota/studio
/plugin install studio@studio-marketplace
```

### For Code Projects
```bash
/build "your goal here"
```

### For Brand & Content
```bash
/brand:init              # Establish brand identity first
/blog "topic"            # Create brand-aligned content
```

---

## Commands

### Build Commands

| Command | Description |
|---------|-------------|
| `/build <goal>` | Start build |
| `/build:preview` | Preview plan |
| `/build:interactive` | Step-by-step |
| `/build resume` | Continue |
| `/build status` | Check state |
| `/build abort` | Cancel |

### Brand Commands

| Command | Description |
|---------|-------------|
| `/brand` or `/brand:init` | Start brand discovery |
| `/brand:update [target]` | Update identity, voice, audience, or messaging |
| `/brand:audit` | Review brand files for consistency |
| `/brand:export [format]` | Export brand guide (md, json) |

### Content Commands

| Command | Description |
|---------|-------------|
| `/blog "topic"` | Create full blog post |
| `/blog:outline "topic"` | Create outline only |
| `/blog:audit "url"` | Audit existing content |
| `/blog:series "theme"` | Plan content series |
| `/blog:ideas` | Generate topic ideas |

---

## Directory Structure

```
studio/
├── agents/                 # Agent definitions
│   ├── planner.yaml
│   ├── builder.yaml
│   └── content-writer.yaml
│
├── brand/                  # Brand source of truth
│   ├── identity.yaml       # Mission, vision, values
│   ├── voice.yaml          # Tone, vocabulary
│   ├── audiences/          # Audience profiles
│   ├── messaging/          # Value props, objections
│   └── templates/          # Content templates
│
├── commands/               # Command definitions
│   ├── build.md
│   ├── brand.md
│   └── blog.md
│
├── memory/                 # User preferences
│   ├── global.md
│   └── [domain].md
│
├── playbooks/              # Methodologies
│   ├── planning/
│   ├── building/
│   ├── reviewing/
│   ├── memory/
│   ├── brand/
│   └── content/
│
├── schemas/                # Validation schemas
│   ├── plan.schema.json
│   ├── brand.schema.json
│   └── blog-post.schema.json
│
└── team/                   # Domain experts
    ├── tier1/
    │   ├── business-analyst.md
    │   ├── brand-strategist.md
    │   └── ...
    ├── tier2/
    └── tier3/
```

---

## Workflow: Code

```
/build "Add user authentication"
         │
         ▼
┌─────────────────────────────────────┐
│  PHASE 1: PLAN                      │
│  • Load playbooks and team          │
│  • Ask requirements questions       │
│  • Embed memory + brand context     │
│  • Create execution-ready plan      │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  PHASE 2: BUILD                     │
│  • Execute micro-actions            │
│  • Validate each step               │
│  • Retry with embedded hints        │
│  • Quality gate on completion       │
└─────────────────────────────────────┘
         │
         ▼
    ✓ BUILD COMPLETE
```

---

## Workflow: Brand & Content

```
/brand:init
         │
         ▼
┌─────────────────────────────────────┐
│  BRAND DISCOVERY                    │
│  • Identity (mission, values)       │
│  • Audience (who you serve)         │
│  • Voice (how you sound)            │
│  • Positioning (market position)    │
│  • Messaging (what you say)         │
└─────────────────────────────────────┘
         │
         ▼
    brand/*.yaml (source of truth)
         │
         ▼
/blog "topic"
         │
         ▼
┌─────────────────────────────────────┐
│  CONTENT CREATION                   │
│  • Load brand context               │
│  • Strategic diagnosis              │
│  • Problem-first architecture       │
│  • Voice-consistent drafting        │
│  • SEO optimization                 │
│  • Brand verification               │
└─────────────────────────────────────┘
         │
         ▼
    Brand-aligned content
```

---

## License

MIT
