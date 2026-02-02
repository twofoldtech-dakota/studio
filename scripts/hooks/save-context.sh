#!/bin/bash
# save-context.sh - Saves critical state before context compaction
# Called by PreCompact hook to preserve task state

set -e

# Plugin source directory (for reading agents, playbooks, etc.)
STUDIO_DIR="${STUDIO_DIR:-studio}"
# Output directory in user's project (for writing data)
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"
RECOVERY_FILE="${STUDIO_OUTPUT_DIR}/.recovery.json"

# Read hook input
INPUT=$(cat)

# Find current task directory
find_current_task() {
    # Look for task with in_progress status
    for manifest in "$STUDIO_OUTPUT_DIR"/projects/*/tasks/*/manifest.json; do
        if [ -f "$manifest" ]; then
            status=$(jq -r '.status // empty' "$manifest" 2>/dev/null)
            if [ "$status" = "BUILDING" ] || [ "$status" = "IN_PROGRESS" ]; then
                dirname "$manifest"
                return
            fi
        fi
    done

    # Fallback: most recent task
    ls -td "$STUDIO_OUTPUT_DIR"/projects/*/tasks/*/ 2>/dev/null | head -1
}

TASK_DIR=$(find_current_task)

if [ -z "$TASK_DIR" ] || [ ! -d "$TASK_DIR" ]; then
    # No active task, nothing to save
    exit 0
fi

# Read current state
PLAN_FILE="${TASK_DIR}/plan.json"
MANIFEST_FILE="${TASK_DIR}/manifest.json"

if [ ! -f "$PLAN_FILE" ]; then
    exit 0
fi

# Extract critical info to preserve
TASK_ID=$(jq -r '.task_id // "unknown"' "$MANIFEST_FILE" 2>/dev/null || echo "unknown")
GOAL=$(jq -r '.goal // "unknown"' "$PLAN_FILE" 2>/dev/null || echo "unknown")
CURRENT_STEP=$(jq -r '.current_step // 0' "$MANIFEST_FILE" 2>/dev/null || echo "0")
TOTAL_STEPS=$(jq '.steps | length' "$PLAN_FILE" 2>/dev/null || echo "0")
STATUS=$(jq -r '.status // "unknown"' "$MANIFEST_FILE" 2>/dev/null || echo "unknown")

# Get completed steps
COMPLETED_STEPS=$(jq -r '.steps[] | select(.status == "completed") | .id' "$MANIFEST_FILE" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

# Save recovery state
cat > "$RECOVERY_FILE" << EOF
{
  "saved_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "task_dir": "$TASK_DIR",
  "task_id": "$TASK_ID",
  "goal": "$GOAL",
  "status": "$STATUS",
  "progress": {
    "current_step": $CURRENT_STEP,
    "total_steps": $TOTAL_STEPS,
    "completed_steps": "$COMPLETED_STEPS"
  },
  "memory_rules_file": "$STUDIO_DIR/memory/global.md"
}
EOF

# Log that we saved (to stderr, won't affect hook output)
echo "[STUDIO] Context saved for recovery: task=$TASK_ID, step=$CURRENT_STEP/$TOTAL_STEPS" >&2

exit 0
