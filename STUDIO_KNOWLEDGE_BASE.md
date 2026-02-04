# STUDIO Knowledge Base

> **Version**: 1.0.0 | **Last Updated**: 2026-02-04
>
> Active architectural evolution through learned constraints and patterns.

This knowledge base contains **verified patterns** from actual build cycles. Entries are promoted based on occurrence thresholds and measurable impact.

---

## Strict Constraints

> Rules that kill performance, quality, or maintainability. **Never violate these.**
>
> **Promotion Threshold:** 2+ occurrences across different tasks

<!-- Entry Format:
### SC-XXX: [Title]
**What**: Never do X
**Why**: Evidence from task_ids
**Instead**: Do Y
**Source**: task_xxx, task_yyy
**Occurrences**: N
**Last Violated**: YYYY-MM-DD
-->

*No entries yet. Constraints are promoted from the Pending Queue after 2+ occurrences.*

---

## Slop Ledger

> Naming conventions, structural mistakes, and style violations that cause rework.
>
> **Promotion Threshold:** 1 occurrence + documented rework impact

<!-- Entry Format:
### SL-XXX: [Title]
**Pattern**: What was wrong
**Fix**: How it should be done
**Rework Cost**: Description of time/effort wasted
**Source**: task_xxx
**Date**: YYYY-MM-DD
-->

*No entries yet. Slop is captured when naming/structural issues cause rework.*

---

## Performance Delta

> Measured before/after improvements. **Must have concrete numbers.**
>
> **Requirement:** Quantified metrics (latency, memory, bundle size, etc.)

<!-- Entry Format:
### PD-XXX: [Title]
**Metric**: What was measured
**Before**: Value with units
**After**: Value with units
**Delta**: Improvement percentage
**How**: What change caused the improvement
**Source**: task_xxx
**Date**: YYYY-MM-DD
-->

*No entries yet. Performance improvements are logged with measured deltas.*

---

## Pending Queue

> Signals awaiting promotion. Items move to appropriate sections when thresholds are met.

<!-- Pending items are tracked here before promotion:
- Item with 1 occurrence stays here
- After 2nd occurrence, promote to Strict Constraints
- Framework-specific items need skill injection match to promote
-->

*No pending items.*

---

## Statistics

| Section | Count | Last Updated |
|---------|-------|--------------|
| Strict Constraints | 0 | - |
| Slop Ledger | 0 | - |
| Performance Delta | 0 | - |
| Pending Queue | 0 | - |

---

## Changelog

<!-- Track significant additions and deletions -->

*Knowledge base initialized on YYYY-MM-DD.*
