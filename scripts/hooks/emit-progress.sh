#!/usr/bin/env bash
#
# STUDIO Progress Emitter Hook
# ============================
#
# Emits progress updates after file operations.
# Called by PostToolUse hook on Edit|Write.
#
# Reads from build-output.json (preferred) or manifest for progress info.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-studio}"
PROJECTS_DIR="${STUDIO_DIR}/projects"
OUTPUT_SCRIPT="${SCRIPT_DIR}/../output.sh"
BUILD_OUTPUT_SCRIPT="${SCRIPT_DIR}/../build-output.sh"

# Read hook input
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Find the active task directory (with build-output.json or manifest.json)
find_active_task_dir() {
    local latest=""
    local latest_time=0

    for task_dir in "$PROJECTS_DIR"/*/tasks/*/; do
        if [[ -d "$task_dir" ]]; then
            local build_output="${task_dir}build-output.json"
            local manifest="${task_dir}manifest.json"

            # Prefer build-output.json
            if [[ -f "$build_output" ]]; then
                local status
                status=$(jq -r '.status // "unknown"' "$build_output" 2>/dev/null)

                # Only consider active builds
                case "$status" in
                    in_progress|pending|paused|awaiting_quality_gate)
                        local updated
                        updated=$(jq -r '.timestamps.updated_at // ""' "$build_output" 2>/dev/null)

                        if [[ -n "$updated" ]] && [[ "$updated" != "null" ]]; then
                            local update_time
                            update_time=$(date -d "$updated" +%s 2>/dev/null || echo 0)

                            if [[ $update_time -gt $latest_time ]]; then
                                latest_time=$update_time
                                latest="$task_dir"
                            fi
                        else
                            if [[ -z "$latest" ]]; then
                                latest="$task_dir"
                            fi
                        fi
                        ;;
                esac
            elif [[ -f "$manifest" ]]; then
                # Fallback to manifest
                local status
                status=$(jq -r '.status // "unknown"' "$manifest" 2>/dev/null)

                case "$status" in
                    BUILDING|IN_PROGRESS|GATHERING|PLANNING)
                        local updated
                        updated=$(jq -r '.updated_at // ""' "$manifest" 2>/dev/null)

                        if [[ -n "$updated" ]] && [[ "$updated" != "null" ]]; then
                            local update_time
                            update_time=$(date -d "$updated" +%s 2>/dev/null || echo 0)

                            if [[ $update_time -gt $latest_time ]]; then
                                latest_time=$update_time
                                latest="$task_dir"
                            fi
                        else
                            if [[ -z "$latest" ]]; then
                                latest="$task_dir"
                            fi
                        fi
                        ;;
                esac
            fi
        fi
    done

    echo "$latest"
}

TASK_DIR=$(find_active_task_dir)

# If no active task, exit silently
if [[ -z "$TASK_DIR" ]] || [[ ! -d "$TASK_DIR" ]]; then
    exit 0
fi

BUILD_OUTPUT="${TASK_DIR}build-output.json"
MANIFEST="${TASK_DIR}manifest.json"

# Read progress info - prefer build-output.json
if [[ -f "$BUILD_OUTPUT" ]]; then
    # Read from build-output.json (detailed progress)
    TASK_ID=$(jq -r '.task_id // "unknown"' "$BUILD_OUTPUT" 2>/dev/null)
    STATUS=$(jq -r '.status // "unknown"' "$BUILD_OUTPUT" 2>/dev/null)
    TOTAL_STEPS=$(jq -r '.execution_summary.total_steps // 1' "$BUILD_OUTPUT" 2>/dev/null)
    COMPLETED_STEPS=$(jq -r '.execution_summary.completed_steps // 0' "$BUILD_OUTPUT" 2>/dev/null)
    IN_PROGRESS_STEP=$(jq -r '[.steps[] | select(.status == "in_progress")] | first | .name // "Working..."' "$BUILD_OUTPUT" 2>/dev/null)

    CURRENT_STEP=$COMPLETED_STEPS
    CURRENT_ACTION="$IN_PROGRESS_STEP"
elif [[ -f "$MANIFEST" ]]; then
    # Fallback to manifest
    TASK_ID=$(jq -r '.id // "unknown"' "$MANIFEST" 2>/dev/null)
    STATUS=$(jq -r '.status // "unknown"' "$MANIFEST" 2>/dev/null)
    CURRENT_STEP=$(jq -r '.progress.current_step // 0' "$MANIFEST" 2>/dev/null)
    TOTAL_STEPS=$(jq -r '.progress.total_steps // 1' "$MANIFEST" 2>/dev/null)
    CURRENT_ACTION=$(jq -r '.progress.current_action // "Working..."' "$MANIFEST" 2>/dev/null)
else
    exit 0
fi

# Get just the filename for current action if generic
if [[ "$CURRENT_ACTION" == "Working..." ]] || [[ "$CURRENT_ACTION" == "null" ]]; then
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
