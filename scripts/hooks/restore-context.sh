#!/bin/bash
# restore-context.sh - Restores critical state after context compaction
# Called by SessionStart(compact) hook to re-inject task context
# Output goes to stdout and is added to Claude's context

set -e

STUDIO_DIR="${STUDIO_DIR:-studio}"
RECOVERY_FILE="${STUDIO_DIR}/.recovery.json"

# Check if we have saved state
if [ ! -f "$RECOVERY_FILE" ]; then
    exit 0
fi

# Read recovery state
TASK_ID=$(jq -r '.task_id // empty' "$RECOVERY_FILE")
GOAL=$(jq -r '.goal // empty' "$RECOVERY_FILE")
STATUS=$(jq -r '.status // empty' "$RECOVERY_FILE")
CURRENT_STEP=$(jq -r '.progress.current_step // 0' "$RECOVERY_FILE")
TOTAL_STEPS=$(jq -r '.progress.total_steps // 0' "$RECOVERY_FILE")
COMPLETED=$(jq -r '.progress.completed_steps // empty' "$RECOVERY_FILE")
TASK_DIR=$(jq -r '.task_dir // empty' "$RECOVERY_FILE")

if [ -z "$TASK_ID" ] || [ "$TASK_ID" = "unknown" ]; then
    exit 0
fi

# Output context to stdout (gets injected into Claude's context)
cat << EOF

=== STUDIO CONTEXT RECOVERY ===

You were working on a task before context compaction. Here's the critical state:

**Task:** $TASK_ID
**Goal:** $GOAL
**Status:** $STATUS
**Progress:** Step $CURRENT_STEP of $TOTAL_STEPS

**Completed steps:** $COMPLETED

**Important files:**
- Plan: ${TASK_DIR}/plan.json
- Manifest: ${TASK_DIR}/manifest.json

**Next action:** Continue from where you left off. Read the plan.json to see the next step.

=== END CONTEXT RECOVERY ===

EOF

# Clean up recovery file (one-time use)
rm -f "$RECOVERY_FILE"

exit 0
