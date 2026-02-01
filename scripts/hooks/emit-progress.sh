#!/usr/bin/env bash
#
# STUDIO Progress Emitter Hook
# ============================
#
# Emits progress updates after file operations.
# Called by PostToolUse hook on Edit|Write.
#
# Reads the active manifest and displays current progress.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-studio}"
PROJECTS_DIR="${STUDIO_DIR}/projects"
OUTPUT_SCRIPT="${SCRIPT_DIR}/../output.sh"

# Read hook input
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Find the active manifest
find_active_manifest() {
    local latest=""
    local latest_time=0

    for manifest in "$PROJECTS_DIR"/*/tasks/*/manifest.json; do
        if [[ -f "$manifest" ]]; then
            local status
            status=$(jq -r '.status // "unknown"' "$manifest" 2>/dev/null)

            # Only consider active builds
            case "$status" in
                BUILDING|IN_PROGRESS|GATHERING|PLANNING)
                    local updated
                    updated=$(jq -r '.updated_at // ""' "$manifest" 2>/dev/null)

                    if [[ -n "$updated" ]] && [[ "$updated" != "null" ]]; then
                        local update_time
                        update_time=$(date -d "$updated" +%s 2>/dev/null || echo 0)

                        if [[ $update_time -gt $latest_time ]]; then
                            latest_time=$update_time
                            latest="$manifest"
                        fi
                    else
                        # No timestamp, but it's active, use it
                        if [[ -z "$latest" ]]; then
                            latest="$manifest"
                        fi
                    fi
                    ;;
            esac
        fi
    done

    echo "$latest"
}

MANIFEST=$(find_active_manifest)

# If no active manifest, exit silently
if [[ -z "$MANIFEST" ]] || [[ ! -f "$MANIFEST" ]]; then
    exit 0
fi

# Read progress info from manifest
TASK_ID=$(jq -r '.id // "unknown"' "$MANIFEST" 2>/dev/null)
STATUS=$(jq -r '.status // "unknown"' "$MANIFEST" 2>/dev/null)
PHASE=$(jq -r '.progress.phase // "building"' "$MANIFEST" 2>/dev/null)
CURRENT_STEP=$(jq -r '.progress.current_step // 0' "$MANIFEST" 2>/dev/null)
TOTAL_STEPS=$(jq -r '.progress.total_steps // 1' "$MANIFEST" 2>/dev/null)
CURRENT_ACTION=$(jq -r '.progress.current_action // "Working..."' "$MANIFEST" 2>/dev/null)

# Get just the filename for current action
if [[ "$CURRENT_ACTION" == "Working..." ]]; then
    CURRENT_ACTION="Edited: $(basename "$FILE_PATH")"
fi

# Calculate progress percentage
[[ "$TOTAL_STEPS" -eq 0 ]] && TOTAL_STEPS=1
PCT=$((CURRENT_STEP * 100 / TOTAL_STEPS))

# Output progress info (to stderr so it doesn't interfere with hook response)
if [[ -x "$OUTPUT_SCRIPT" ]]; then
    "$OUTPUT_SCRIPT" progress_bar "$CURRENT_STEP" "$TOTAL_STEPS" "Build" >&2
else
    # Fallback to simple text output
    echo "[STUDIO] Progress: $CURRENT_STEP/$TOTAL_STEPS ($PCT%) - $CURRENT_ACTION" >&2
fi

exit 0
