---
name: context-management
description: Intelligent context window management with tiered content, token budgets, and LLM-powered summarization
triggers:
  - "context"
  - "optimize"
  - "summarize"
  - "budget"
  - "token"
---

# Context Management Skill: Intelligent Token Budget Control

This skill teaches the methodology for managing context window efficiently. It prevents context bloat, enables long-running sessions, and preserves critical information through intelligent summarization.

## The Core Problem

Context windows have hard limits. Without management:
- Learnings files grow unbounded
- Plans store full documentation
- Tool outputs accumulate
- Sessions fail mid-task

## The Solution: Three-Tier Content System

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONTEXT TIER SYSTEM                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  TIER 1: FULL CONTENT (Recent/Active)                              │
│  ══════════════════════                                            │
│  • Age: < 30 days                                                  │
│  • Token Retention: 100%                                           │
│  • Content: Complete entries with all details                      │
│  • Preserves: Code snippets, full explanations, all context        │
│                                                                     │
│  ────────────────────────────────────────────────────────────────  │
│                                                                     │
│  TIER 2: SUMMARY (Older)                                           │
│  ══════════════════════                                            │
│  • Age: 30-90 days                                                 │
│  • Token Retention: 20-30%                                         │
│  • Content: LLM-generated summaries                                │
│  • Preserves: Key insights, pattern names, problem-solution pairs  │
│                                                                     │
│  ────────────────────────────────────────────────────────────────  │
│                                                                     │
│  TIER 3: INDEX ONLY (Archived)                                     │
│  ═════════════════════════════                                     │
│  • Age: > 90 days                                                  │
│  • Token Retention: 5%                                             │
│  • Content: Metadata only                                          │
│  • Preserves: Date, title, domain, tags, reference path            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Token Budget Allocation

The total context window must be allocated across competing needs:

```
TOTAL BUDGET: ~150,000 tokens
────────────────────────────────────────────────────────────

Pool           │ Soft Limit │ Hard Limit │ Purpose
───────────────┼────────────┼────────────┼───────────────────
Reserved       │   30,000   │   35,000   │ System prompts,
               │            │            │ playbooks, task
───────────────┼────────────┼────────────┼───────────────────
Learnings      │   20,000   │   25,000   │ Project learnings
               │            │            │ from builds
───────────────┼────────────┼────────────┼───────────────────
Backlog        │   15,000   │   20,000   │ Epic/Feature/Task
               │            │            │ hierarchy
───────────────┼────────────┼────────────┼───────────────────
Plans          │   30,000   │   35,000   │ Current plan
               │            │            │ details
───────────────┼────────────┼────────────┼───────────────────
Context7       │   25,000   │   30,000   │ External docs
               │            │            │ from MCP
───────────────┼────────────┼────────────┼───────────────────
Working        │   30,000   │   40,000   │ Agent workspace,
               │            │            │ tool results
────────────────────────────────────────────────────────────
```

### Budget Thresholds

- **80% (Warning)**: Start monitoring, consider optimization
- **95% (Force)**: Must optimize before continuing

## Token Estimation Methods

Different content types have different token densities:

### Code Content
```
Tokens ≈ Characters / 4

Example:
  1000 characters of code ≈ 250 tokens
```

### Markdown/Text Content
```
Tokens ≈ Words × 1.3

Example:
  500 words of markdown ≈ 650 tokens
```

### JSON Content
```
Tokens ≈ Characters / 3.3

Example:
  2000 characters of JSON ≈ 606 tokens
```

## LLM-Powered Summarization

When entries age into Tier 2, use Claude to create intelligent summaries.

### Summarization Prompt Template

```
Summarize this learning entry, preserving:
1. The key insight (one sentence)
2. Pattern names mentioned
3. Code snippets (keep if < 10 lines, describe otherwise)
4. Problem-solution pairs

Original entry:
[CONTENT]

Output format:
## [Date]: [Title] (summarized)
**Key Insight:** [One sentence capturing the main lesson]
**Patterns:** [Comma-separated pattern names]
**Ref:** [original-file-path]
```

### Example Transformation

**Original (Tier 1, 800 tokens):**
```markdown
## 2025-11-15: Form Validation Pattern

**Context:** Building user registration (task_20251115_143052)

**What Worked:**
- Zod + react-hook-form for client-side validation
- Inline error display with immediate feedback
- Server-side validation mirroring client rules
- Using FormProvider for nested forms

**Problems Solved:**
- Problem: Form submission not showing errors
  Solution: Added `mode: "onBlur"` to react-hook-form config

- Problem: Async validation for email uniqueness
  Solution: Used resolver with async validation

**Pattern:**
```typescript
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8).regex(/[A-Z]/).regex(/[0-9]/)
});

const form = useForm({
  resolver: zodResolver(schema),
  mode: "onBlur",
  reValidateMode: "onChange"
});

// For async validation
const resolver = async (data) => {
  const result = schema.safeParse(data);
  if (!result.success) return { values: {}, errors: result.error };

  const emailExists = await checkEmail(data.email);
  if (emailExists) {
    return { values: {}, errors: { email: { message: "Email taken" } } };
  }
  return { values: data, errors: {} };
};
```

**Anti-patterns:**
- Don't validate on every keystroke (performance)
- Don't show all errors at once (overwhelming)
```

**Summarized (Tier 2, 180 tokens):**
```markdown
## 2025-11-15: Form Validation Pattern (summarized)

**Key Insight:** Use Zod + react-hook-form with `mode: "onBlur"` for optimal validation UX; mirror validation rules server-side.

**Patterns:** zodResolver, FormProvider, async-resolver, onBlur-validation

**Problem-Solutions:**
- Form errors not showing → Add `mode: "onBlur"`
- Async email validation → Custom resolver with await

**Ref:** studio/learnings/frontend.md#2025-11-15
```

### Summary Caching

Summaries are cached to avoid re-summarization:
```
.studio/.cache/summaries/
├── frontend_2025-11-15.md
├── backend_2025-11-01.md
└── ...
```

## Context Optimization Workflow

### 1. Check Current Status
```bash
./scripts/context-manager.sh status
```

### 2. Scan for Optimization Opportunities
```bash
./scripts/context-manager.sh scan
```

Output shows:
- Entries by tier
- Entries needing summarization
- Entries needing archival
- Token usage vs budget

### 3. Generate Summarization Prompts
```bash
./scripts/context-manager.sh summarize studio/learnings/frontend.md 2025-11-15
```

### 4. Apply Summaries
After LLM generates summary:
1. Replace original entry with summary
2. Cache the summary
3. Keep original in archive (optional)

## Preservation Rules

### Always Preserve in Tier 1
- Entries referenced by active tasks
- Entries from last 7 days regardless of size
- Entries tagged with `#preserve`

### Never Summarize
- Security-critical patterns (full context needed)
- Entries with `#no-summarize` tag
- Integration patterns with complex code

## Integration with Other Systems

### Learnings System
The context manager works with learnings.sh:
- Monitors learnings file sizes
- Triggers summarization at thresholds
- Maintains domain organization

### Orchestrator
The orchestrator allocates context budgets:
- Planner gets more for plan storage
- Builder gets more for tool results
- Shared learnings budget

### Session Management
At session start:
1. Load tier-1 entries fully
2. Load tier-2 summaries
3. Load tier-3 indexes
4. Track usage as session progresses

## Best Practices

### 1. Monitor Continuously
Check budget status at session start and after large operations.

### 2. Summarize Proactively
Don't wait for hard limit. Summarize when warnings appear.

### 3. Prioritize Recent
Recent content is more likely to be relevant. Preserve it.

### 4. Trust the Tier System
30/90 day thresholds are tuned for typical project cycles.

### 5. Cache Everything
Summaries are expensive. Never regenerate unnecessarily.

## Troubleshooting

### "Context budget exceeded"
1. Run `context-manager.sh optimize learnings`
2. Remove unused plan context
3. Clear Context7 cache for unused libraries

### "Summarization quality poor"
1. Check if entry has code > 50 lines
2. Consider preserving as-is with `#no-summarize`
3. Manually edit summary to preserve key details

### "Missing historical context"
1. Check tier-3 index for reference
2. Load original from archive if needed
3. Consider promoting back to tier-1

---

*"Manage context like memory: keep what's recent, summarize what's older, index what's ancient."*
