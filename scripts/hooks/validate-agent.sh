#!/usr/bin/env bash
#
# STUDIO Subagent Stop Validator
# =============================
#
# Validates that STUDIO agents have properly written their JSON outputs.
# This script is called by the SubagentStop hook.
#
# Arguments:
#   $1 - Agent name (planner, builder, verifier)
#
# Exit codes:
#   0 - Approved (JSON files written correctly)
#   2 - Blocked (missing or invalid JSON files)
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
TASKS_DIR="${STUDIO_DIR}/tasks"

# Find the active task directory
find_active_task() {
    if [[ ! -d "$TASKS_DIR" ]]; then
        return 1
    fi

    # Find task with non-complete status
    local task_dir
    for task_dir in "$TASKS_DIR"/task_*/; do
        if [[ -d "$task_dir" ]]; then
            local state_file="${task_dir}state.json"
            if [[ -f "$state_file" ]]; then
                local status
                status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
                if [[ "$status" != "COMPLETE" && "$status" != "FAILED" && "$status" != "ABORTED" ]]; then
                    echo "${task_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

# Validate Planner (Planing) output
validate_planner() {
    local task_dir="$1"
    local plan_file="${task_dir}/plan.json"
    local state_file="${task_dir}/state.json"

    # Check if plan.json exists
    if [[ ! -f "$plan_file" ]]; then
        echo '{"decision": "block", "reason": "Plan JSON not written: plan.json is missing"}'
        exit 0
    fi

    # Check if plan has required fields
    if ! grep -q '"id"' "$plan_file" || ! grep -q '"task_id"' "$plan_file"; then
        echo '{"decision": "block", "reason": "Plan JSON invalid: missing id or task_id"}'
        exit 0
    fi

    # Check if state.json has plan_id
    if [[ -f "$state_file" ]] && ! grep -q '"plan_id"' "$state_file"; then
        echo '{"decision": "block", "reason": "State not updated: plan_id not set"}'
        exit 0
    fi

    # Plan valid, allow stopping
    exit 0
}

# Validate Builder output
validate_builder() {
    local task_dir="$1"
    local build_log="${task_dir}/build-log.json"

    # Check if build-log.json exists
    if [[ ! -f "$build_log" ]]; then
        echo '{"decision": "block", "reason": "Build log JSON not written: build-log.json is missing"}'
        exit 0
    fi

    # Check if build log has required fields
    if ! grep -q '"plan_id"' "$build_log" || ! grep -q '"records"' "$build_log"; then
        echo '{"decision": "block", "reason": "Build log JSON invalid: missing plan_id or records"}'
        exit 0
    fi

    # Build log valid, allow stopping
    exit 0
}

# Validate Verifier output
validate_verifier() {
    local task_dir="$1"
    local verify_report="${task_dir}/verify-report.json"

    # Check if verify-report.json exists
    if [[ ! -f "$verify_report" ]]; then
        echo '{"decision": "block", "reason": "Verify report JSON not written: verify-report.json is missing"}'
        exit 0
    fi

    # Check if verify report has verdict
    local verdict
    verdict=$(grep -o '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "$verify_report" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

    if [[ -z "$verdict" ]]; then
        echo '{"decision": "block", "reason": "Verify report JSON invalid: missing verdict"}'
        exit 0
    fi

    # Verify report valid, allow stopping
    exit 0
}

# Main
main() {
    local agent_name="${1:-}"

    # Normalize agent name to lowercase
    agent_name=$(echo "$agent_name" | tr '[:upper:]' '[:lower:]')

    # Find active task
    local task_dir
    if ! task_dir=$(find_active_task); then
        # No active task found, allow stopping
        exit 0
    fi

    case "$agent_name" in
        planner)
            validate_planner "$task_dir"
            ;;
        builder)
            validate_builder "$task_dir"
            ;;
        verifier)
            validate_verifier "$task_dir"
            ;;
        *)
            # Unknown agent, allow stopping
            exit 0
            ;;
    esac
}

main "$@"
