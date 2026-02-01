#!/bin/bash
# inject-context.sh - Injects relevant task context on user prompts
# Called by UserPromptSubmit hook
# Output goes to stdout and is added to Claude's context

set -e

STUDIO_DIR="${STUDIO_DIR:-studio}"

# Read hook input (contains the user's prompt)
INPUT=$(cat)

# Find active task
find_active_task() {
    for manifest in "$STUDIO_DIR"/projects/*/tasks/*/manifest.json; do
        if [ -f "$manifest" ]; then
            status=$(jq -r '.status // empty' "$manifest" 2>/dev/null)
            if [ "$status" = "BUILDING" ] || [ "$status" = "IN_PROGRESS" ] || [ "$status" = "READY_TO_BUILD" ]; then
                dirname "$manifest"
                return
            fi
        fi
    done
}

TASK_DIR=$(find_active_task)

# If no active task, don't inject anything
if [ -z "$TASK_DIR" ] || [ ! -d "$TASK_DIR" ]; then
    exit 0
fi

PLAN_FILE="${TASK_DIR}/plan.json"
MANIFEST_FILE="${TASK_DIR}/manifest.json"

if [ ! -f "$PLAN_FILE" ]; then
    exit 0
fi

# Extract current state
GOAL=$(jq -r '.goal // "unknown"' "$PLAN_FILE" 2>/dev/null)
STATUS=$(jq -r '.status // "unknown"' "$MANIFEST_FILE" 2>/dev/null)
CURRENT_STEP=$(jq -r '.current_step // 0' "$MANIFEST_FILE" 2>/dev/null)
TOTAL_STEPS=$(jq '.steps | length' "$PLAN_FILE" 2>/dev/null)

# Get current step name
STEP_NAME=$(jq -r ".steps[$CURRENT_STEP].name // \"unknown\"" "$PLAN_FILE" 2>/dev/null)

# Only inject if there's an active build
if [ "$STATUS" = "BUILDING" ] || [ "$STATUS" = "IN_PROGRESS" ]; then
    cat << EOF

[STUDIO Context: Active task "$GOAL" - Step $((CURRENT_STEP + 1))/$TOTAL_STEPS: $STEP_NAME]

EOF
fi

exit 0
