#!/usr/bin/env bash
#
# STUDIO PreToolUse Validator
# ==========================
#
# Verifies that Write/Edit tool calls align with the current blueprint step.
# This is a lightweight check - detailed validation happens in PostToolUse.
#
# Exit codes:
#   0 - Allow (tool call aligns or no active cast)
#   2 - Block (tool call doesn't match blueprint)
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
CASTS_DIR="${STUDIO_DIR}/casts"

# Read hook input from stdin
INPUT=$(cat)

# Extract tool info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Find active cast
find_active_cast() {
    if [[ ! -d "$CASTS_DIR" ]]; then
        return 1
    fi

    local cast_dir
    for cast_dir in "$CASTS_DIR"/cast_*/; do
        if [[ -d "$cast_dir" ]]; then
            local state_file="${cast_dir}state.json"
            if [[ -f "$state_file" ]]; then
                local status
                status=$(jq -r '.status // empty' "$state_file" 2>/dev/null)
                if [[ "$status" == "CASTING" || "$status" == "in_progress" ]]; then
                    echo "${cast_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

main() {
    # If no file path, allow (not a file operation we care about)
    if [[ -z "$FILE_PATH" ]]; then
        exit 0
    fi

    # Find active cast
    local cast_dir
    if ! cast_dir=$(find_active_cast); then
        # No active cast, allow the operation
        exit 0
    fi

    local blueprint_file="${cast_dir}/blueprint.json"
    local state_file="${cast_dir}/state.json"

    # If no blueprint, allow
    if [[ ! -f "$blueprint_file" ]]; then
        exit 0
    fi

    # Get current step
    local current_step
    current_step=$(jq -r '.current_step // empty' "$state_file" 2>/dev/null)

    if [[ -z "$current_step" ]]; then
        # No current step tracked, allow
        exit 0
    fi

    # Check if this file_path is expected in current step's micro_actions
    local expected_paths
    expected_paths=$(jq -r ".steps[] | select(.id == \"$current_step\") | .micro_actions[]? | select(.tool == \"Write\" or .tool == \"Edit\") | .file_path // .params.file_path // empty" "$blueprint_file" 2>/dev/null)

    # Also check main action
    local main_action_path
    main_action_path=$(jq -r ".steps[] | select(.id == \"$current_step\") | .action.parameters.file_path // empty" "$blueprint_file" 2>/dev/null)

    # Combine expected paths
    all_expected="$expected_paths"$'\n'"$main_action_path"

    # If this path is in expected paths, allow
    if echo "$all_expected" | grep -qF "$FILE_PATH"; then
        exit 0
    fi

    # Check if path is in produces list (broader match)
    local produces
    produces=$(jq -r ".steps[] | select(.id == \"$current_step\") | .produces[]? // empty" "$blueprint_file" 2>/dev/null)

    # Allow if we can't definitively say it's wrong
    # (This is a soft check - PostToolUse does the real validation)
    exit 0
}

main "$@"
