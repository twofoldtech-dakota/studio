---
name: analytics
description: View STUDIO build analytics and metrics
triggers:
  - "/analytics"
  - "/analytics:dashboard"
  - "/analytics:recent"
  - "/analytics:export"
---

# STUDIO Analytics

View build metrics, success rates, and historical trends.

## Commands

### `/analytics` or `/analytics:dashboard`
Display the main analytics dashboard.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/analytics.sh" dashboard 30
```

Shows:
- Build summary (total, complete, failed, halted, aborted)
- Success rate with visual progress bar
- Averages (duration, steps, retries)
- Quality verdict breakdown (STRONG, SOUND, UNSTABLE, BLOCKED)

### `/analytics:recent [count]`
Show recent builds with status.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/analytics.sh" recent 10
```

### `/analytics:export [format]`
Export analytics data.

```bash
# JSON (default)
"${CLAUDE_PLUGIN_ROOT}/scripts/analytics.sh" export json

# CSV
"${CLAUDE_PLUGIN_ROOT}/scripts/analytics.sh" export csv > builds.csv

# Summary only
"${CLAUDE_PLUGIN_ROOT}/scripts/analytics.sh" export summary
```

## Dashboard Output

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

## Data Storage

Analytics are stored in `studio/data/analytics.json`:

```json
{
  "version": "1.0.0",
  "created_at": "2026-01-15T10:00:00Z",
  "builds": [
    {
      "id": "task_20260201_120000",
      "status": "COMPLETE",
      "duration_ms": 45000,
      "steps": 6,
      "retries": 1,
      "verdict": "STRONG",
      "completed_at": "2026-02-01T12:00:45Z"
    }
  ],
  "summary": {
    "total": 24,
    "complete": 20,
    "failed": 2,
    "aborted": 1,
    "halted": 1
  }
}
```

## Integration

Analytics are logged automatically via the Stop hook when a build completes:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/analytics.sh" log \
  "$TASK_ID" \
  "$STATUS" \
  "$DURATION_MS" \
  "$TOTAL_STEPS" \
  "$TOTAL_RETRIES" \
  "$VERDICT"
```

## Insights

Use analytics to:
- Track build success rate over time
- Identify common failure patterns
- Monitor average build duration
- See which quality verdicts are most common
- Export data for external analysis
