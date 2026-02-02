#!/usr/bin/env bash
#
# STUDIO Stop Hook Validator
# =========================
#
# Validates that STUDIO tasks are properly completed before stopping.
# This script is called by the Stop hook to ensure verifying was performed.
#
# Exit codes:
#   0 - Approved (not an STUDIO task, or properly completed)
#   2 - Blocked (STUDIO task incomplete or failed verifying)
#

set -euo pipefail

# Plugin source directory (for reading agents, playbooks, etc.)
STUDIO_DIR="${STUDIO_DIR:-studio}"
# Output directory in user's project (for writing data)
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"
TASKS_DIR="${STUDIO_OUTPUT_DIR}/tasks"

# Check if this is an STUDIO session by looking for active tasks
check_studio_session() {
    if [[ ! -d "$TASKS_DIR" ]]; then
        # No STUDIO tasks directory, allow stopping
        exit 0
    fi

    # Find the most recent task directory
    local latest_task
    latest_task=$(find "$TASKS_DIR" -maxdepth 1 -type d -name "task_*" 2>/dev/null | sort -r | head -1)

    if [[ -z "$latest_task" ]]; then
        # No STUDIO tasks found, allow stopping
        exit 0
    fi

    echo "$latest_task"
}

# Validate a task's completion state
validate_task() {
    local task_dir="$1"
    local state_file="${task_dir}/state.json"
    local verify_file="${task_dir}/verify-report.json"

    # Check if state.json exists
    if [[ ! -f "$state_file" ]]; then
        # No active task state, allow stopping
        exit 0
    fi

    # Read the status from state.json
    local status
    status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

    # If status is COMPLETE, we're good
    if [[ "$status" == "COMPLETE" ]]; then
        # Exit 0 with no decision = allow stopping
        exit 0
    fi

    # If status is INITIALIZING, PLANNING, or BUILDING, check if user is abandoning
    case "$status" in
        INITIALIZING|PLANNING|BUILDING)
            # Allow stopping during these phases (user may want to cancel)
            exit 0
            ;;
        VERIFYING)
            # During verifying, check if verify report exists
            if [[ ! -f "$verify_file" ]]; then
                echo '{"decision": "block", "reason": "STUDIO task incomplete: Verifying phase in progress. Please wait for verifying to complete."}'
                exit 0
            fi
            ;;
        FAILED|ABORTED)
            # Allow stopping if task already failed or aborted
            exit 0
            ;;
    esac

    # Check verify report if it exists
    if [[ -f "$verify_file" ]]; then
        local verdict
        verdict=$(grep -o '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "$verify_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

        case "$verdict" in
            STRONG|SOUND)
                # Task verified successfully, allow stopping
                exit 0
                ;;
            UNSTABLE)
                echo '{"decision": "block", "reason": "STUDIO task incomplete: UNSTABLE verdict - Issues need to be fixed before completion."}'
                exit 0
                ;;
            FAILED)
                echo '{"decision": "block", "reason": "STUDIO task incomplete: FAILED verdict - Critical issues prevent completion."}'
                exit 0
                ;;
        esac
    fi

    # Default: allow if we can't determine state
    exit 0
}

# Main
main() {
    local task_dir
    task_dir=$(check_studio_session)

    # If check_studio_session exited, we're done
    # Otherwise, validate the task
    if [[ -n "$task_dir" && -d "$task_dir" ]]; then
        validate_task "$task_dir"
    fi
}

main
