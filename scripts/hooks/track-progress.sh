#!/bin/bash
# track-progress.sh - Automatically tracks progress after file operations
# Called by PostToolUse hook on Edit|Write

set -e

STUDIO_DIR="${STUDIO_DIR:-studio}"

# Read hook input
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Find active task
find_active_task() {
    for manifest in "$STUDIO_DIR"/projects/*/tasks/*/manifest.json; do
        if [ -f "$manifest" ]; then
            status=$(jq -r '.status // empty' "$manifest" 2>/dev/null)
            if [ "$status" = "BUILDING" ] || [ "$status" = "IN_PROGRESS" ]; then
                echo "$manifest"
                return
            fi
        fi
    done
}

MANIFEST_FILE=$(find_active_task)

if [ -z "$MANIFEST_FILE" ] || [ ! -f "$MANIFEST_FILE" ]; then
    exit 0
fi

TASK_DIR=$(dirname "$MANIFEST_FILE")
PLAN_FILE="${TASK_DIR}/plan.json"

if [ ! -f "$PLAN_FILE" ]; then
    exit 0
fi

# Record the file change in manifest
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Add to artifacts list if not already there
EXISTING=$(jq -r ".artifacts // [] | .[] | select(.path == \"$FILE_PATH\") | .path" "$MANIFEST_FILE" 2>/dev/null)

if [ -z "$EXISTING" ]; then
    # Add new artifact
    jq --arg path "$FILE_PATH" --arg time "$TIMESTAMP" \
        '.artifacts = (.artifacts // []) + [{"path": $path, "created_at": $time, "type": "file"}]' \
        "$MANIFEST_FILE" > "${MANIFEST_FILE}.tmp" && mv "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"
fi

# Update last activity
jq --arg time "$TIMESTAMP" '.updated_at = $time' "$MANIFEST_FILE" > "${MANIFEST_FILE}.tmp" && mv "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"

# Log progress (to stderr)
echo "[STUDIO] Tracked: $FILE_PATH" >&2

exit 0
