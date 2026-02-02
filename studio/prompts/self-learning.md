# Self-Learning System Prompt

> Learning is part of Definition of Done. A task is NOT complete until learning is captured.

## Core Principle

Every completed task produces knowledge. This knowledge must be:
1. **Extracted** - Identified from the task execution
2. **Classified** - Assigned to the correct destination
3. **Deduplicated** - Checked against existing knowledge
4. **Promoted** - Moved to appropriate knowledge base section when thresholds are met

---

## Mandatory Extraction Fields

When capturing a learning, ALL of the following must be specified:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| `task_id` | YES | Reference to the source task | `task_20240215_auth_fix` |
| `domain` | YES | Category of the learning | `frontend`, `backend`, `testing`, `security`, `performance`, `global` |
| `impact_type` | YES | Type of impact | `constraint`, `slop`, `performance`, `pattern` |
| `severity` | YES | Importance level | `HIGH`, `MEDIUM`, `LOW` |
| `measurable_outcome` | IF APPLICABLE | Before/after metrics | `LCP: 2.4s -> 1.1s` |

---

## Impact Type Definitions

### constraint
A rule that, when violated, causes significant problems.
- **Destination**: Strict Constraints (after 2+ occurrences) or Pending Queue (1 occurrence)
- **Examples**: "Never mutate state directly in React", "Always validate user input before DB operations"

### slop
A naming, structural, or stylistic mistake that causes rework.
- **Destination**: Slop Ledger (immediately on 1st occurrence with rework evidence)
- **Examples**: "Used camelCase for CSS classes instead of kebab-case", "Put utility functions in component files"

### performance
A measurable improvement in speed, memory, or efficiency.
- **Destination**: Performance Delta (requires numbers)
- **Examples**: "Lazy loading reduced initial bundle by 40%", "Query optimization cut API latency by 200ms"

### pattern
A reusable approach or technique that worked well.
- **Destination**: Domain-specific learnings file (studio/learnings/{domain}.md)
- **Examples**: "Custom hook pattern for API calls", "Test fixture factory pattern"

---

## Severity Criteria

| Severity | Criteria |
|----------|----------|
| **HIGH** | Caused failure, data loss, security issue, or >1 hour of debugging |
| **MEDIUM** | Caused rework, confusion, or required significant refactoring |
| **LOW** | Minor improvement, good-to-know, or preference-based |

---

## Definition of Done Checklist

A task is NOT complete until:

- [ ] **Learning Extracted**: At least one learning captured from the task
- [ ] **Fields Complete**: All mandatory extraction fields populated
- [ ] **Classification Applied**: Learning assigned to correct impact_type
- [ ] **Duplicate Check**: Knowledge base scanned for similar existing entries
- [ ] **Sprint Counter Updated**: `.studio/sprint-counter.json` incremented
- [ ] **Evolution Check**: If 5th task in sprint, trigger evolution protocol

---

## Classification Decision Tree

```
START: New learning from task
  |
  +--> Does it involve MEASURED performance improvement?
  |      YES --> Performance Delta (requires numbers)
  |      NO  --> Continue
  |
  +--> Did it cause REWORK due to naming/structure?
  |      YES --> Slop Ledger
  |      NO  --> Continue
  |
  +--> Is it a rule that MUST NOT be violated?
  |      YES --> Has it occurred before?
  |              YES (2+) --> Strict Constraints
  |              NO (1st) --> Pending Queue
  |      NO  --> Continue
  |
  +--> Is it a reusable PATTERN or technique?
         YES --> Domain learnings (studio/learnings/{domain}.md)
         NO  --> Consider if it's actually worth capturing
```

---

## Signal vs. Noise Criteria

### CAPTURE (Signal)
- Has specific task_id reference
- Describes something that went wrong OR exceptionally right
- Can be applied to future similar tasks
- Has measurable or observable impact

### DO NOT CAPTURE (Noise)
- No task_id reference
- Contains: "how to", "basic", "simple", "standard", "obvious"
- Generic programming concepts (unless project-specific twist)
- Already exists in knowledge base
- No measurable or describable impact

---

## Entry Templates

### For Strict Constraints / Pending Queue
```markdown
### SC-XXX: [Brief Title]
**What**: Never do [specific action]
**Why**: [Evidence from task - what went wrong]
**Instead**: Do [correct approach]
**Source**: [task_id(s)]
**Occurrences**: [count]
```

### For Slop Ledger
```markdown
### SL-XXX: [Brief Title]
**Pattern**: [What was wrong]
**Fix**: [How it should be done]
**Rework Cost**: [Time/effort wasted]
**Source**: [task_id]
**Date**: [YYYY-MM-DD]
```

### For Performance Delta
```markdown
### PD-XXX: [Brief Title]
**Metric**: [What was measured]
**Before**: [Value with units]
**After**: [Value with units]
**Delta**: [Improvement %]
**How**: [What caused improvement]
**Source**: [task_id]
**Date**: [YYYY-MM-DD]
```

### For Domain Learnings
```markdown
## YYYY-MM-DD: [Brief Title]

**Context:** [Task description, what you were trying to do]
**Task ID:** [task_id]

**What Worked:**
- [Item 1]
- [Item 2]

**Problems Solved:**
- Problem: [Description]
  Solution: [How it was fixed]

**Pattern:**
```code
[Reusable code example if applicable]
```
```

---

## Integration with Sprint Evolution

Every 5 tasks, the sprint evolution protocol triggers:
1. Review learnings from the sprint
2. Propose rules for deletion (no violations in 10+ tasks)
3. Propose new enforcement rules (highest-impact patterns)
4. Present proposals for user approval
5. Update STUDIO_KNOWLEDGE_BASE.md on acceptance

The sprint counter at `.studio/sprint-counter.json` tracks progress.
