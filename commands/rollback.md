---
name: rollback
description: Rollback to pre-task state using git snapshots
triggers:
  - "/rollback"
  - "/rollback:list"
  - "/rollback:preview"
  - "/rollback:to"
---

# Rollback System

Git-based snapshots for task-level rollback capability.

## Overview

The rollback system creates git tags before each task starts, allowing you to:
- Preview what a rollback would change
- Restore files to their pre-task state
- Maintain audit trail of all snapshots

## Commands

### `/rollback` or `/rollback:list`
List available rollback points.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback.sh" list
```

### `/rollback:preview <task_id>`
Preview what would be reverted without making changes.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback.sh" preview task_20260201_120000
```

### `/rollback:to <task_id>`
Rollback to pre-task state.

```bash
# Preview first (no --force)
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback.sh" to task_20260201_120000

# Execute rollback
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback.sh" to task_20260201_120000 --force
```

## How It Works

### 1. Snapshot Creation
Before each task starts, a git tag is created:
```
git tag -a studio-task-<task_id> -m "STUDIO snapshot before task"
```

### 2. Rollback Execution
Rollback uses git checkout to restore files:
```
git checkout studio-task-<task_id> -- .
```

### 3. Changes Are Staged
After rollback, changes are staged but not committed:
- Review the changes
- Make any adjustments
- Commit when satisfied

## Output Example

```
╔══════════════════════════════════════════════════════════════╗
║  ROLLBACK POINTS                                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  task_20260201_150000                                        ║
║  ├─ Date:   2026-02-01                                       ║
║  ├─ Commit: a1b2c3d4                                         ║
║  └─ Since:  5 files changed, 150 insertions(+), 30 deletions(-)
║                                                              ║
║  task_20260201_120000                                        ║
║  ├─ Date:   2026-02-01                                       ║
║  ├─ Commit: e5f6g7h8                                         ║
║  └─ Since:  12 files changed, 400 insertions(+), 50 deletions(-)
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Snapshot Log

Snapshots are logged to `studio/data/snapshots.json`:

```json
{
  "snapshots": [
    {
      "task_id": "task_20260201_120000",
      "tag": "studio-task-task_20260201_120000",
      "commit": "a1b2c3d4e5f6g7h8",
      "created_at": "2026-02-01T12:00:00Z"
    }
  ]
}
```

## Integration

Snapshots are created automatically via SubagentStart hook:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback.sh" create "$TASK_ID"
```

## Best Practices

1. **Always preview first** - Use `/rollback:preview` before `/rollback:to`
2. **Commit important changes** - Uncommitted changes block rollback (use --force to override)
3. **Review after rollback** - Changes are staged, review before committing
4. **Clean up old snapshots** - Run `rollback.sh cleanup 30` to remove old tags

## Cleanup

Remove old snapshots to keep repository clean:

```bash
# Remove snapshots older than 30 days (default)
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback.sh" cleanup

# Remove snapshots older than 7 days
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback.sh" cleanup 7
```

## Safety

- Rollback requires `--force` to execute (prevents accidents)
- Original snapshots are preserved even after rollback
- Uncommitted changes block rollback by default
- All rollbacks can themselves be rolled back (git reflog)
