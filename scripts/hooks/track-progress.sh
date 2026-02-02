#!/bin/bash
# track-progress.sh - Automatically tracks progress after file operations
# Called by PostToolUse hook on Edit|Write

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Plugin source directory (for reading agents, playbooks, etc.)
STUDIO_DIR="${STUDIO_DIR:-studio}"
# Output directory in user's project (for writing data)
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"
BUILD_OUTPUT_SCRIPT="${SCRIPT_DIR}/../build-output.sh"

# Read hook input
INPUT=$(cat)

# Extract file path and tool name from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Determine artifact type based on tool
ARTIFACT_TYPE="modified"
if [ "$TOOL_NAME" = "Write" ]; then
    # Check if file existed before (simple heuristic: if it's a new file)
    # In practice, Write could be creating or overwriting
    ARTIFACT_TYPE="created"
fi

# Find active task
find_active_task() {
    for manifest in "$STUDIO_OUTPUT_DIR"/projects/*/tasks/*/manifest.json; do
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
BUILD_OUTPUT_FILE="${TASK_DIR}/build-output.json"

if [ ! -f "$PLAN_FILE" ]; then
    exit 0
fi

# Extract task_id from the directory name or manifest
TASK_ID=$(basename "$TASK_DIR")

# Get current step from environment or manifest
CURRENT_STEP="${STUDIO_CURRENT_STEP:-}"
if [ -z "$CURRENT_STEP" ] && [ -f "$BUILD_OUTPUT_FILE" ]; then
    CURRENT_STEP=$(jq -r '[.steps[] | select(.status == "in_progress")] | first | .id // empty' "$BUILD_OUTPUT_FILE" 2>/dev/null)
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

# Also update build-output.json if it exists and we have a current step
if [ -f "$BUILD_OUTPUT_FILE" ] && [ -n "$CURRENT_STEP" ] && [ -x "$BUILD_OUTPUT_SCRIPT" ]; then
    "$BUILD_OUTPUT_SCRIPT" artifact "$TASK_ID" "$CURRENT_STEP" "$FILE_PATH" "$ARTIFACT_TYPE" 2>/dev/null || true
fi

# Log progress (to stderr)
echo "[STUDIO] Tracked: $FILE_PATH" >&2

exit 0
