#!/usr/bin/env bash
#
# STUDIO Plan Validator
# =========================
#
# Validates that the Architect agent has produced a complete,
# TASK-READY plan before allowing it to stop.
#
# Exit codes:
#   0 - Approved (plan is complete and valid)
#   Returns JSON with decision:block if invalid
#

set -euo pipefail

# Plugin source directory (for reading agents, playbooks, etc.)
STUDIO_DIR="${STUDIO_DIR:-studio}"
# Output directory in user's project (for writing data)
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"
TASKS_DIR="${STUDIO_OUTPUT_DIR}/tasks"

# Find active task
find_active_task() {
    if [[ ! -d "$TASKS_DIR" ]]; then
        return 1
    fi

    local task_dir
    for task_dir in "$TASKS_DIR"/task_*/; do
        if [[ -d "$task_dir" ]]; then
            local state_file="${task_dir}state.json"
            if [[ -f "$state_file" ]]; then
                local status
                status=$(jq -r '.status // empty' "$state_file" 2>/dev/null)
                if [[ "$status" == "READY_TO_BUILD" || "$status" == "PLANNING" ]]; then
                    echo "${task_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

validate_plan() {
    local plan_file="$1"
    local errors=()

    # Check required top-level fields
    local has_id has_task_id has_goal has_steps

    has_id=$(jq -r '.id // empty' "$plan_file" 2>/dev/null)
    has_task_id=$(jq -r '.task_id // empty' "$plan_file" 2>/dev/null)
    has_goal=$(jq -r '.goal // empty' "$plan_file" 2>/dev/null)
    has_steps=$(jq -r '.steps | length' "$plan_file" 2>/dev/null)

    if [[ -z "$has_id" ]]; then
        errors+=("Missing plan id")
    fi

    if [[ -z "$has_task_id" ]]; then
        errors+=("Missing task_id")
    fi

    if [[ -z "$has_goal" ]]; then
        errors+=("Missing goal")
    fi

    if [[ "$has_steps" == "0" || -z "$has_steps" ]]; then
        errors+=("No steps defined")
    fi

    # Check embedded_context (TASK-READY requirement)
    local has_embedded_context
    has_embedded_context=$(jq -r '.embedded_context // empty' "$plan_file" 2>/dev/null)

    if [[ -z "$has_embedded_context" || "$has_embedded_context" == "null" ]]; then
        errors+=("Missing embedded_context - plan not TASK-READY")
    fi

    # Check each step has required fields
    local step_count
    step_count=$(jq -r '.steps | length' "$plan_file" 2>/dev/null)

    for ((i=0; i<step_count; i++)); do
        local step_id
        local has_action
        local has_success_criteria

        step_id=$(jq -r ".steps[$i].id // empty" "$plan_file" 2>/dev/null)
        has_action=$(jq -r ".steps[$i].action // empty" "$plan_file" 2>/dev/null)
        has_success_criteria=$(jq -r ".steps[$i].success_criteria | length" "$plan_file" 2>/dev/null)

        if [[ -z "$step_id" ]]; then
            errors+=("Step $i missing id")
        fi

        if [[ -z "$has_action" || "$has_action" == "null" ]]; then
            errors+=("Step $step_id missing action")
        fi

        if [[ "$has_success_criteria" == "0" || -z "$has_success_criteria" ]]; then
            errors+=("Step $step_id has no success_criteria - not self-validating")
        fi

        # Check success_criteria have validation_commands
        local criteria_count
        criteria_count=$(jq -r ".steps[$i].success_criteria | length" "$plan_file" 2>/dev/null)

        for ((j=0; j<criteria_count; j++)); do
            local has_validation_cmd
            has_validation_cmd=$(jq -r ".steps[$i].success_criteria[$j].validation_command // empty" "$plan_file" 2>/dev/null)

            if [[ -z "$has_validation_cmd" ]]; then
                errors+=("Step $step_id criterion $j missing validation_command - not executable")
            fi
        done

        # Check retry_behavior exists
        local has_retry
        has_retry=$(jq -r ".steps[$i].retry_behavior // empty" "$plan_file" 2>/dev/null)

        if [[ -z "$has_retry" || "$has_retry" == "null" ]]; then
            errors+=("Step $step_id missing retry_behavior")
        fi
    done

    # Check validation_hooks exist (TASK-READY requirement)
    local has_quality_gate
    has_quality_gate=$(jq -r '.validation_hooks.quality_gate // empty' "$plan_file" 2>/dev/null)

    if [[ -z "$has_quality_gate" || "$has_quality_gate" == "null" ]]; then
        errors+=("Missing validation_hooks.quality_gate - no quality assurance defined")
    fi

    # Return errors if any
    if [[ ${#errors[@]} -gt 0 ]]; then
        local error_list
        error_list=$(printf '%s\\n' "${errors[@]}")
        echo "$error_list"
        return 1
    fi

    return 0
}

main() {
    # Find active task
    local task_dir
    if ! task_dir=$(find_active_task); then
        # No active task, allow
        exit 0
    fi

    local plan_file="${task_dir}/plan.json"

    # Check if plan.json exists
    if [[ ! -f "$plan_file" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Plan JSON not written: plan.json is missing. The Architect must write the plan to .studio/tasks/[task_id]/plan.json before stopping."
}
EOF
        exit 0
    fi

    # Validate plan
    local validation_errors
    if ! validation_errors=$(validate_plan "$plan_file"); then
        cat << EOF
{
  "decision": "block",
  "reason": "Plan validation failed. The plan is not TASK-READY.",
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "PLAN VALIDATION ERRORS:\\n\\n$validation_errors\\n\\nFix these issues before the plan can be approved."
  }
}
EOF
        exit 0
    fi

    # Plan is valid
    exit 0
}

main "$@"
